# Moves each pinned flake input to the newest commit pushed to its branch at
# least COOLDOWN_DAYS ago, and only ever forward.
#
# Usage: update [INPUT...]   (default: every GitHub input except nixpkgs)
#
# Environment:
#   COOLDOWN_DAYS  minimum age of a push in days (default 7, 0 for urgent updates)
#   DRY_RUN        if non-empty, only print what would change
#   SUMMARY_FILE   if set, append a Markdown summary of the changes to this file
#   GH_TOKEN       GitHub token for the API (gh's own login works locally)
#   SELECT_JQ      path to select.jq (set by the flake)

cooldown_days=${COOLDOWN_DAYS:-7}
cutoff=$(date -u -d "-${cooldown_days} days" +%Y-%m-%dT%H:%M:%SZ)

# Direct inputs from GitHub that follow a branch. nixpkgs is excluded: it only
# exists so that the pinned flakes share one, and consumers replace it.
# shellcheck disable=SC2016 # $nodes is a jq variable, not a shell one
pinnable='
  .nodes as $nodes
  | $nodes.root.inputs
  | to_entries[]
  | select(.key != "nixpkgs" and (.value | type) == "string")
  | select($nodes[.value].original | .type == "github" and (has("rev") | not))
  | .key'

if (($# > 0)); then
  names=("$@")
else
  mapfile -t names < <(jq -r "$pinnable" flake.lock)
fi

# Whether commit $2 equals or descends from commit $1.
is_ancestor() {
  local status
  status=$(gh api "repos/$repo/compare/$1...$2" --jq .status)
  [[ $status == ahead || $status == identical ]]
}

echo "Cooldown: $cooldown_days days (pushes at or before $cutoff)" >&2
changes=()
for name in "${names[@]}"; do
  node=$(jq -r --arg name "$name" '.nodes.root.inputs[$name] // empty' flake.lock)
  if [[ -z $node ]] || ! jq -e --arg name "$name" "[$pinnable] | index(\$name)" flake.lock >/dev/null; then
    echo "$name: not a pinnable input" >&2
    exit 1
  fi
  repo=$(jq -r --arg node "$node" '.nodes[$node].original | "\(.owner)/\(.repo)"' flake.lock)
  branch=$(jq -r --arg node "$node" '.nodes[$node].original.ref // empty' flake.lock)
  locked=$(jq -r --arg node "$node" '.nodes[$node].locked.rev' flake.lock)
  if [[ -z $branch ]]; then
    branch=$(gh api "repos/$repo" --jq .default_branch)
  fi

  found=$(gh api --paginate --slurp "repos/$repo/activity?ref=refs/heads/$branch&per_page=100" |
    jq -r --arg cutoff "$cutoff" -f "$SELECT_JQ")
  if [[ -z $found ]]; then
    echo "$name: no push to $branch before the cutoff" >&2
    continue
  fi
  read -r rev pushed_at <<<"$found"

  if [[ $rev == "$locked" ]]; then
    echo "$name: up to date" >&2
    continue
  fi
  # A force push may have removed the commit from the branch since.
  if ! is_ancestor "$rev" "$branch"; then
    echo "$name: ${rev:0:9} is no longer on $branch, skipping" >&2
    continue
  fi
  # Never move backwards, e.g. after an urgent update with a cooldown of 0.
  if ! is_ancestor "$locked" "$rev"; then
    echo "$name: ${rev:0:9} doesn't descend from ${locked:0:9}, skipping" >&2
    continue
  fi

  echo "$name: ${locked:0:9} -> ${rev:0:9} (pushed $pushed_at)" >&2
  changes+=("- $name: [\`${locked:0:9}\` → \`${rev:0:9}\`](https://github.com/$repo/compare/$locked...$rev), pushed to $branch $pushed_at")
  if [[ -z ${DRY_RUN:-} ]]; then
    nix flake lock --override-input "$name" "github:$repo/$rev"
  fi
done

if ((${#changes[@]} == 0)); then
  echo "Nothing to update" >&2
elif [[ -n ${SUMMARY_FILE:-} ]]; then
  {
    echo "Cooldown: $cooldown_days days"
    echo
    printf '%s\n' "${changes[@]}"
  } >>"$SUMMARY_FILE"
fi

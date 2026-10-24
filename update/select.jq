# The newest push to a branch at or before $cutoff.
#
# Input: the pages of GitHub's repository activity API for one branch
# (`gh api --paginate --slurp`), each newest first.
# Output: "<commit> <timestamp>" of that push, or nothing.
#
# Any activity that moves the branch counts (push, force_push, pr_merge,
# merge_queue_merge); a deleted branch points nowhere. Timestamps are
# ISO 8601 in UTC, so they compare as strings.
add // []
| map(select(.activity_type != "branch_deletion" and .timestamp <= $cutoff))
| first // empty
| "\(.after) \(.timestamp)"

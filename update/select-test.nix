# Runs select.jq against hand-written activity pages. Pure: no network.
{ pkgs }:

let
  push = after: timestamp: {
    activity_type = "push";
    inherit after timestamp;
  };

  cases = {
    "takes the newest push before the cutoff" = {
      pages = [
        [
          (push "c3" "2026-10-20T10:00:00Z")
          (push "c2" "2026-10-12T10:00:00Z")
          (push "c1" "2026-10-01T10:00:00Z")
        ]
      ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "c2 2026-10-12T10:00:00Z";
    };

    "includes a push exactly at the cutoff" = {
      pages = [ [ (push "c1" "2026-10-15T00:00:00Z") ] ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "c1 2026-10-15T00:00:00Z";
    };

    "finds nothing when every push is younger" = {
      pages = [ [ (push "c1" "2026-10-20T10:00:00Z") ] ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "";
    };

    "finds nothing without activity" = {
      pages = [ ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "";
    };

    "skips a branch deletion" = {
      pages = [
        [
          {
            activity_type = "branch_deletion";
            after = "0000000000000000000000000000000000000000";
            timestamp = "2026-10-10T10:00:00Z";
          }
          (push "c1" "2026-10-01T10:00:00Z")
        ]
      ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "c1 2026-10-01T10:00:00Z";
    };

    "counts a force push and a merged pull request" = {
      pages = [
        [
          {
            activity_type = "force_push";
            after = "f1";
            timestamp = "2026-10-12T10:00:00Z";
          }
          {
            activity_type = "pr_merge";
            after = "m1";
            timestamp = "2026-10-11T10:00:00Z";
          }
        ]
      ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "f1 2026-10-12T10:00:00Z";
    };

    "looks beyond the first page" = {
      pages = [
        [ (push "c3" "2026-10-20T10:00:00Z") ]
        [ (push "c2" "2026-10-12T10:00:00Z") ]
      ];
      cutoff = "2026-10-15T00:00:00Z";
      expected = "c2 2026-10-12T10:00:00Z";
    };
  };

  check = name: case: ''
    actual=$(jq -r --arg cutoff ${case.cutoff} -f ${./select.jq} ${pkgs.writeText "pages.json" (builtins.toJSON case.pages)})
    if [ "$actual" != ${pkgs.lib.escapeShellArg case.expected} ]; then
      echo "FAIL: ${name}: expected '${case.expected}', got '$actual'"
      exit 1
    fi
    echo "ok: ${name}"
  '';
in
pkgs.runCommand "select-test" { nativeBuildInputs = [ pkgs.jq ]; } ''
  ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList check cases)}
  touch $out
''

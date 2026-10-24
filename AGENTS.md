# Agent guidelines

## This repository is public

Never add private information: not in files, commit messages, branch names, pull requests or
issues. That includes names of private repositories, hostnames, network details, addresses,
secrets, and anything about the owner's infrastructure or projects. Describe consumers of the
pins generically.

## Commits

- **One logical change per commit**, each building and passing `nix flake check` on its own.
- **Every commit has a message:** a short imperative subject line (≤ 72 characters), a blank
  line, then a body explaining _why_ and anything non-obvious. Skip the body only when the
  subject says everything.
- Work on a branch and open a pull request. Only the update workflow commits to `main` directly.

## Cooldown

- Never pin a flake to a commit that hasn't passed the 7-day cooldown, except as an explicit
  urgent update.
- GitHub Actions are pinned by commit SHA to releases at least 7 days old.

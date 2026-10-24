# nix-pins

Third-party Nix flakes I trust after a cooldown.

Each flake here is pinned to the newest commit that was pushed to its branch **at least 7 days
ago**. A compromised or broken commit upstream thereby has a week to be noticed before it reaches
anything that follows these pins.

| Input                     | Upstream                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------- |
| `pyproject-nix`           | [pyproject-nix/pyproject.nix](https://github.com/pyproject-nix/pyproject.nix)         |
| `uv2nix`                  | [pyproject-nix/uv2nix](https://github.com/pyproject-nix/uv2nix)                       |
| `pyproject-build-systems` | [pyproject-nix/build-system-pkgs](https://github.com/pyproject-nix/build-system-pkgs) |

## How the cooldown works

- **Age is push time, not commit date.** A commit's date is set by its author and can be
  backdated. The age used here is when GitHub recorded the push that put the commit on the branch
  ([repository activity API](https://docs.github.com/en/rest/repos/repos#list-repository-activities)).
- **Only forward.** A pin only moves to a commit that is still on its branch and descends from
  the current pin.
- **Daily.** [`update.yml`](.github/workflows/update.yml) runs `nix run .#update` every morning
  and commits the new lock file to `main`.
- **Urgent updates.** Run the workflow manually with a cooldown of 0, optionally for selected
  inputs only.

Locally:

```sh
DRY_RUN=1 nix run .#update          # show what would change
COOLDOWN_DAYS=0 nix run .#update uv2nix
```

## Using the pins

Follow the inputs instead of declaring them yourself, and give the pins your own nixpkgs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    pins = {
      url = "github:ytausch/nix-pins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix.follows = "pins/uv2nix";
    pyproject-nix.follows = "pins/pyproject-nix";
    pyproject-build-systems.follows = "pins/pyproject-build-systems";
  };
}
```

`nix flake update pins` then picks up whatever has passed the cooldown.

## Why nixpkgs isn't here

nixpkgs is a monorepo: a pin covers all packages at once, so a security fix can't be taken
without every other commit before it. On a stable channel, changes are reviewed backports and
only reach the channel after Hydra has built them, and a large share of them are security fixes.
A cooldown would mostly delay those. The `nixpkgs` input here only exists so that the pinned
flakes share one; consumers replace it with their own.

## Adding a flake

Add it as an input in [`flake.nix`](flake.nix), with `follows` for anything it shares with the
other pins, and lock it to a commit that has already passed the cooldown (the update app never
moves a pin backwards). Inputs from GitHub that follow a branch are picked up by the update app
automatically.

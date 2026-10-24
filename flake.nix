{
  description = "Third-party flakes, pinned after a 7-day cooldown";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      checks = forAllSystems (pkgs: {
        select = import ./update/select-test.nix { inherit pkgs; };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}

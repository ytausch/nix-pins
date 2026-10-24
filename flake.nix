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
      packages = forAllSystems (pkgs: {
        # `nix run .#update`: move the pins forward, honouring the cooldown.
        update = pkgs.writeShellApplication {
          name = "update";
          # nix itself comes from the caller, who is running `nix run` anyway.
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gh
            pkgs.jq
          ];
          runtimeEnv.SELECT_JQ = "${./update/select.jq}";
          text = builtins.readFile ./update/update.sh;
        };
      });

      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.update;
        };
      });

      checks = forAllSystems (pkgs: {
        select = import ./update/select-test.nix { inherit pkgs; };
        # Building it runs shellcheck on update.sh.
        update = self.packages.${pkgs.stdenv.hostPlatform.system}.update;
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}

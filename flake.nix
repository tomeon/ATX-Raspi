{
  description = "Description for the project";

  inputs = {
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} ({
      inputs,
      moduleWithSystem,
      self,
      ...
    }: {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      imports = [
        inputs.devshell.flakeModule
        inputs.treefmt-nix.flakeModule

        ./nix/checks.nix
        ./nix/devshells.nix
        ./nix/nixos-modules.nix
        ./nix/packages.nix
      ];

      flake = {
        nixosConfigurations = {
          default = inputs.nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.atx-raspi
              {
                boot.isContainer = true;
                fileSystems."/".fsType = "tmpfs";
                nixpkgs.hostPlatform = "x86_64-linux";
                system.stateVersion = "24.11";
              }
            ];
          };
        };
      };

      perSystem = {
        config,
        lib,
        ...
      }: {
        apps = lib.mapAttrs (lib.const (lib.getAttr "flakeApp")) config.devShells;

        treefmt = {config, ...}: {
          flakeFormatter = true;
          projectRootFile = "flake.nix";

          programs = {
            alejandra.enable = true;
            gofumpt.enable = true;
            ruff.enable = true;
            shellcheck.enable = true;
            shfmt.enable = true;
          };

          settings.formatter = lib.mkIf config.programs.shfmt.enable {
            # Empty out the CLI options list so that `shfmt` uses the settings
            # from `.editorconfig`.
            shfmt.options = lib.mkForce [];
          };
        };
      };
    });
}

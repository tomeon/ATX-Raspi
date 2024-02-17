{
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    devShells = {
      default = config.devShells.atx-raspi;
    };

    devshells = {
      atx-raspi = {extraModulesPath, ...}: {
        imports = ["${extraModulesPath}/language/go.nix"];

        commands =
          [
            {
              package = pkgs.act;
            }

            {
              package = pkgs.libgpiod;
            }

            {
              package = config.treefmt.build.wrapper;
            }

            {
              name = "mkoptdocs";
              command = ''
                cd "$(git rev-parse --show-cdup)" || exit
                while read -r out_path; do
                  install -Dm0644 "$out_path" ./doc/nixos-modules.md
                done < <(nix build "$@" --no-link --print-out-paths '.#docs')
              '';
              help = "Build NixOS module options documentation";
            }
          ]
          ++ lib.pipe config.packages [
            (lib.flip builtins.removeAttrs ["default"])
            (builtins.attrValues)
            (lib.filter (package: package ? meta.mainProgram))
            (map (package: {inherit package;}))
          ];
      };
    };
  };
}

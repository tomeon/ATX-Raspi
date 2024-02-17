{self, ...}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: {
    packages = {
      default = config.packages.atx-raspi-shutdownirq;

      atx-raspi-shutdownirq = pkgs.callPackage ({
        writers,
        python3,
      }:
        writers.makeScriptWriter {
          inherit (python3.withPackages (p: [p.libgpiod])) interpreter;
        } "/bin/atx-raspi-shutdownirq" (builtins.readFile "${self}/shutdownirq.py")) {};

      atx-raspi-shutdowncheck = pkgs.callPackage ({
        coreutils,
        libgpiod,
        lib,
        writers,
      }:
        writers.writeBashBin "atx-raspi-shutdowncheck" {
          makeWrapperArgs = [
            "--prefix"
            "PATH"
            ":"
            (lib.makeBinPath [coreutils libgpiod])
          ];
        } (builtins.readFile "${self}/shutdowncheck.sh")) {};

      docs = pkgs.callPackage ({
        nixosOptionsDoc,
        lib,
        eval,
      }:
        (nixosOptionsDoc {
          options = {
            inherit (eval.options.services) atx-raspi-shutdown;
          };

          # Default is currently "appendix".
          documentType = "none";

          warningsAreErrors = true;

          transformOptions = let
            ourPrefix = "${toString self}/";
            moduleSource = "flake.nix";
            link = {
              url = "/${moduleSource}";
              name = moduleSource;
            };
          in
            opt:
              opt
              // {
                visible = opt.visible && (lib.any (lib.hasPrefix ourPrefix) opt.declarations);
                declarations = map (decl:
                  if lib.hasPrefix ourPrefix decl
                  then link
                  else decl)
                opt.declarations;
              };
        })
        .optionsCommonMark) {
        eval = self.nixosConfigurations.default.extendModules {
          modules = [
            {
              nixpkgs.hostPlatform = system;
            }
          ];
        };
      };

      gpiosimtest = pkgs.callPackage ./pkgs/gpiosimtest {};
    };
  };
}

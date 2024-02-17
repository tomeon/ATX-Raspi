{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} ({inputs, ...}: {
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    perSystem = {config, lib, pkgs, ...}: {
      checks = {
        atx-raspi-shutdowncheck = pkgs.nixosTest {
          name = "atx-raspi-shutdowncheck";
          nodes = {
            default = {...}: {
              systemd.services.atx-raspi-shutdowncheck = {
                wantedBy = []; # need to start manually
                environment.DRY_RUN = "1";
                serviceConfig = {
                  ExecStart = config.packages.atx-raspi-shutdowncheck;
                };
              };
            };
          };
          testScript = ''
            start_all()
            default.succeed("mkdir -p /sys/class/gpio/gpio{7,8} 1>&2")
            default.systemctl("start atx.raspi-shutdowncheck.service")
            default.wait_for_unit("atx.raspi-shutdowncheck.service")
          '';
        };
      };

      packages = {
        default = config.packages.atx-raspi-shutdownirq;

        atx-raspi-shutdownirq = pkgs.writers.makeScriptWriter {
          inherit (pkgs.python3.withPackages (p: [p.rpi-gpio])) interpreter;
        } "/bin/atx-raspi-shutdownirq" (builtins.readFile ./shutdownirq.py);

        atx-raspi-shutdowncheck = pkgs.runCommand "atx-raspi-shutdowncheck" {
          nativeBuildInputs = [pkgs.makeWrapper];
        } ''
          mkdir -p $out/bin
          cp ${./shutdowncheck.sh} $out/bin/atx-raspi-shutdowncheck.sh
          wrapProgram $out/bin/atx-raspi-shutdowncheck.sh \
            --prefix PATH : ${lib.makeBinPath (with pkgs; [coreutils])}
        '';
      };
    };
  });
}

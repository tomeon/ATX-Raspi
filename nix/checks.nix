{self, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    checks = {
      default = config.checks.atx-raspi;

      atx-raspi = pkgs.nixosTest {
        name = "atx-raspi-shutdown";
        nodes = let
          common = {pkgs, ...}: {
            imports = [self.nixosModules.default];

            boot.kernelModules = ["gpio-sim"];

            environment.systemPackages = with pkgs; [
              curl
              jq
            ];

            security.polkit.debug = true;
            security.polkit.enable = true;

            services.atx-raspi-shutdown.enable = true;

            systemd.services.gpiosimtest = {
              wantedBy = ["multi-user.target"];
              environment.PORT = "8080";
              serviceConfig = {
                ExecStart = lib.getExe config.packages.gpiosimtest;
              };
            };

            systemd.services.atx-raspi-shutdown = {
              wantedBy = lib.mkForce []; # Need to start manually.
              requires = ["gpiosimtest.service"];
              after = ["gpiosimtest.service"];
              environment.ATX_RASPI_DRY_RUN = "1";
            };
          };
        in {
          check = {...}: {
            imports = [common];
            services.atx-raspi-shutdown.implementation = "check";
          };

          irq = {...}: {
            imports = [common];
            services.atx-raspi-shutdown.implementation = "irq";
          };
        };
        testScript = {nodes, ...}: let
          checkURL = "http://localhost:${nodes.check.systemd.services.gpiosimtest.environment.PORT}";
          irqURL = "http://localhost:${nodes.irq.systemd.services.gpiosimtest.environment.PORT}";
        in ''
          import time

          from typing import Optional

          def systemctl_succeed(m: Machine, q: str, user: Optional[str] = None) -> str:
            user_desc = "root"
            if user is not None:
              user_desc = user
            with m.nested(f"command `systemctl {q}` must succeed as {user_desc}"):
              (status, output) = m.systemctl(q, user)

              if status != 0:
                  m.log(f"output: {output}")
                  raise Exception(f"command `systemctl {q}` failed as {user_desc} (exit code {status})")

              return output

          start_all()

          check.succeed("modprobe gpio_sim 1>&2")
          check.succeed("lsmod | grep gpio_sim 1>&2")

          check.wait_for_unit("dbus.service")

          systemctl_succeed(check, "cat polkit.service 1>&2")
          systemctl_succeed(check, "cat atx-raspi-shutdown.service 1>&2")

          systemctl_succeed(irq, "cat polkit.service 1>&2")
          systemctl_succeed(irq, "cat atx-raspi-shutdown.service 1>&2")

          check.wait_for_unit("gpiosimtest.service")
          check_chip = check.succeed("curl ${checkURL}/devpath | jq --raw-output '.data.devpath'").strip()
          systemctl_succeed(check, f"set-environment ATX_RASPI_CHIP={check_chip}")

          irq.wait_for_unit("gpiosimtest.service")
          irq_chip = irq.succeed("curl ${irqURL}/devpath | jq --raw-output '.data.devpath'").strip()
          systemctl_succeed(irq, f"set-environment ATX_RASPI_CHIP={irq_chip}")

          systemctl_succeed(check, "start atx-raspi-shutdown.service")
          check.wait_for_unit("atx-raspi-shutdown.service")
          check.wait_until_succeeds("test $(curl ${checkURL}/line/8/level | jq --raw-output '.data.level') = 1")
          check.wait_until_succeeds("curl -X PUT ${checkURL}/line/7/pull/up | jq 1>&2")
          time.sleep(5)
          check.wait_until_succeeds("curl -X PUT ${checkURL}/line/7/pull/down | jq 1>&2")
          check.wait_until_succeeds(f"journalctl --grep='SHUTDOWN request on chip {check_chip}'")

          systemctl_succeed(irq, "start atx-raspi-shutdown.service")
          irq.wait_for_unit("atx-raspi-shutdown.service")
          irq.wait_until_succeeds("test $(curl ${irqURL}/line/8/level | jq --raw-output '.data.level') = 1")
          irq.wait_until_succeeds("curl -X PUT ${irqURL}/line/7/pull/up | jq 1>&2")
          time.sleep(5)
          irq.wait_until_succeeds("curl -X PUT ${irqURL}/line/7/pull/down | jq 1>&2")
          check.wait_until_succeeds(f"journalctl --grep='SHUTDOWN request on chip {irq_chip}'")
        '';
      };
    };
  };
}

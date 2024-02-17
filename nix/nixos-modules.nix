{
  self,
  moduleWithSystem,
  ...
}: {
  flake = {
    nixosModules = {
      default = self.nixosModules.atx-raspi;

      atx-raspi = moduleWithSystem (
        {config, ...} @ perSystem: {
          config,
          lib,
          options,
          ...
        }: let
          inherit (lib) mkOption types;
          cfg = config.services.atx-raspi-shutdown;
          opts = options.services.atx-raspi-shutdown;
          description = "ATX-Raspi shutdown daemon";
          polkitEnabled = config.security.polkit.enable;
          wrap = lib.replaceStrings ["\n"] [" "];
        in {
          options = {
            services = {
              atx-raspi-shutdown = {
                enable = lib.mkEnableOption "the ${description}";

                implementation = mkOption {
                  type = types.enum ["check" "irq"];
                  default = "irq";
                  example = "check";
                  description = ''
                    GPIO daemon implementation.  "irq" selects the
                    edge-triggered Python implementation.  "check" selects
                    the polling-based shell implementation.
                  '';
                };

                package = mkOption {
                  type = types.package;
                  default = perSystem.config.packages."atx-raspi-shutdown${cfg.implementation}";
                  description = ''
                    Package providing the ATX-Raspi daemon.
                  '';
                };

                chip = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  example = "/dev/gpiochip42";
                  description = ''
                    The path to the GPIO chip.
                  '';
                };

                pins = {
                  shutdown = mkOption {
                    type = types.nullOr types.ints.unsigned;
                    default = null;
                    example = 7;
                    description = ''
                      Pin on {option}`chip` to watch for the shutdown or
                      reboot button press.
                    '';
                  };

                  boot = mkOption {
                    inherit (opts.pins.shutdown) type;
                    default = null;
                    example = 8;
                    description = ''
                      Pin on {option}`chip` to set high upon ATX-Raspi
                      service startup.
                    '';
                  };
                };

                pulses = {
                  reboot = mkOption {
                    type = types.nullOr types.float;
                    default = null;
                    example = 0.2;
                    description = ''
                      Minimum duration of high state on
                      {option}`pins.shutdown` to trigger reboot.
                    '';
                  };

                  shutdown = mkOption {
                    inherit (opts.pulses.reboot) type;
                    default = null;
                    example = 0.6;
                    description = ''
                      Minimum duration of high state on
                      {option}`pins.shutdown` to trigger shutdown.
                    '';
                  };
                };
              };
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.atx-raspi-shutdown = lib.const {
              imports = [
                (lib.mkIf polkitEnabled {
                  #serviceConfig.DynamicUser = true;
                })
              ];

              description = "The ${description}";

              wantedBy = ["basic.target"];

              environment =
                lib.flip lib.pipe [
                  (lib.filterAttrs (_: value: value != null))
                  (lib.mapAttrs' (name: value: {
                    inherit value;
                    name = "ATX_RASPI_${lib.toUpper name}";
                  }))
                ] {
                  inherit (cfg) chip;
                  boot_pin = cfg.pins.boot;
                  shutdown_pin = cfg.pins.shutdown;
                  pulse_min = cfg.pulses.reboot;
                  pulse_max = cfg.pulses.shutdown;
                };

              serviceConfig = {
                UMask = "0027";

                Restart = "always";
                RestartSec = 3;

                BindPaths =
                  [
                    #"/run/dbus/system_bus_socket"
                  ]
                  ++ lib.optional (cfg.chip != null) cfg.chip;

                ExecStart = lib.getExe cfg.package;

                # Security settings
                CapabilityBoundingSet = [""];
                DevicePolicy = "closed";
                DeviceAllow = "char-gpiochip";
                LockPersonality = true;
                MemoryDenyWriteExecute = true;
                NoNewPrivileges = true;
                PrivateDevices = false;
                PrivateIPC = true;
                PrivateTmp = true;
                ProcSubset = "pid";
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectProc = "invisible";
                ProtectSystem = "strict";
                RemoveIPC = true;
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_NETLINK"
                  "AF_UNIX"
                ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
                SystemCallFilter = [
                  "@system-service @resources"
                  "~@privileged"
                ];
              };
            };

            assertions = let
              noNullAttrValues = attrs: lib.all (x: x != null) (builtins.attrValues attrs);
            in [
              {
                assertion = (noNullAttrValues cfg.pins) -> (cfg.pins.boot != cfg.pins.shutdown);
                message = wrap ''
                  atx-raspi: boot pin and shutdown pin must be distinct
                '';
              }

              {
                assertion = (noNullAttrValues cfg.pulses) -> (cfg.pulses.reboot > cfg.pulses.shutdown);
                message = wrap ''
                  atx-raspi: shutdown pulse must be longer than reboot pulse
                  (reboot pulse is ${toString cfg.pulses.reboot}, shutdown
                  pulse is ${toString cfg.pulses.poweroff})
                '';
              }
            ];

            warnings = lib.optional (!polkitEnabled) (wrap ''
              atx-raspi: `security.polkit.enable` is set to `false`; running
              the GPIO daemon as `root`.
            '');

            security.polkit.extraConfig = ''
              // Permit ATX-Raspi service users to power off and reboot
              polkit.addRule(function(action, subject) {
                if (
                  (
                       action.id == "org.freedesktop.login1.power-off"
                    || action.id == "org.freedesktop.login1.power-off-multiple-sessions"
                    || action.id == "org.freedesktop.login1.power-off-ignore-inhibit"
                    || action.id == "org.freedesktop.login1.reboot"
                    || action.id == "org.freedesktop.login1.reboot-multiple-sessions"
                    || action.id == "org.freedesktop.login1.reboot-ignore-inhibit"
                    || action.id == "org.freedesktop.login1.suspend"
                    || action.id == "org.freedesktop.login1.suspend-multiple-sessions"
                    || action.id == "org.freedesktop.login1.suspend-ignore-inhibit"
                    || action.id == "org.freedesktop.login1.hibernate"
                    || action.id == "org.freedesktop.login1.hibernate-multiple-sessions"
                    || action.id == "org.freedesktop.login1.hibernate-ignore-inhibit"
                  ) && subject.user == "${config.systemd.services.atx-raspi-shutdown.serviceConfig.User or "atx-raspi-shutdown"}"
                ) {
                  return polkit.Result.YES;
                }
              });
            '';
          };
        }
      );
    };
  };
}

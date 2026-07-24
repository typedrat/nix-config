{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.matter-server;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.matter-server = {
    enable = options.mkEnableOption "Matter server";

    port = options.mkOption {
      type = types.port;
      default = 5580;
      description = "Port to expose the Matter server on.";
    };

    logLevel = options.mkOption {
      type = types.enum ["critical" "error" "warning" "info" "debug"];
      default = "info";
      description = "Verbosity of logs from the Matter server.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.matter-server = {
        protocol = "ws";
        inherit (cfg) port;
      };

      services.matter-server = {
        enable = true;
        inherit (config.links.matter-server) port;
        inherit (cfg) logLevel;

        # A malformed PAA root certificate in the production DCL (NXP's)
        # otherwise raises ValueError during the startup fetch, killing the
        # server task before the websocket ever binds while the process
        # stays alive and looks healthy to systemd. Skip bad certs instead.
        package = pkgs.python-matter-server.overridePythonAttrs (old: {
          patches = (old.patches or []) ++ [./matter-server-skip-malformed-paa-certs.patch];
        });
      };

      # The upstream module uses DynamicUser which breaks impermanence
      # because systemd's dynamic user/group IDs don't match the static
      # UIDs that impermanence bind-mounts expect.
      systemd.services.matter-server.serviceConfig.DynamicUser = lib.mkForce false;
      users.users.matter-server = {
        isSystemUser = true;
        group = "matter-server";
        home = "/var/lib/matter-server";
      };
      users.groups.matter-server = {};
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/matter-server";
            user = "matter-server";
            group = "matter-server";
          }
        ];
      };
    })
  ];
}

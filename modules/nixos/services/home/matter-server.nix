{
  config,
  lib,
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

    extraArgs = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments to pass to the matter-server executable.";
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
        port = config.links.matter-server.port;
        inherit (cfg) logLevel extraArgs;
      };
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

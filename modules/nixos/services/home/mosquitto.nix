{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.mosquitto;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.mosquitto = {
    enable = options.mkEnableOption "Mosquitto MQTT broker";

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for Mosquitto.";
    };

    users = options.mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          passwordFile = options.mkOption {
            type = types.path;
            description = "Path to a file containing the user's password.";
          };

          acl = options.mkOption {
            type = types.listOf types.str;
            default = [];
            description = ''
              ACL rules for this user. Each rule should be in the format:
              "pattern read topic/path/#" or "topic readwrite topic/path/#"
            '';
            example = [
              "readwrite homeassistant/#"
              "read homeassistant/status"
            ];
          };
        };
      });
      default = {};
      description = ''
        Attribute set of MQTT users with their password files and ACL rules.
        For Home Assistant integration, create a user with appropriate topic access.
      '';
    };

    aclPatterns = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Global ACL patterns applied before user-specific rules.
        These apply to all users on the listener.
      '';
      example = ["pattern read $SYS/#"];
    };

    allowAnonymous = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow anonymous connections.";
    };

    persistence = options.mkOption {
      type = types.bool;
      default = true;
      description = "Enable message and subscription persistence.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.mosquitto = {
        protocol = "mqtt";
      };

      services.mosquitto = {
        enable = true;
        inherit (cfg) persistence;

        listeners = [
          {
            inherit (config.links.mosquitto) port;
            address = "127.0.0.1";

            users =
              lib.mapAttrs (
                _name: userCfg: {
                  inherit (userCfg) passwordFile acl;
                }
              )
              cfg.users;

            acl = cfg.aclPatterns;

            settings = {
              allow_anonymous = cfg.allowAnonymous;
            };
          }
        ];
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [config.links.mosquitto.port];
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.mosquitto.dataDir;
            user = "mosquitto";
            group = "mosquitto";
          }
        ];
      };
    })
  ];
}

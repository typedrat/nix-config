{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.zwave-js;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.zwave-js = {
    enable = options.mkEnableOption "Z-Wave JS server";

    serialPort = options.mkOption {
      type = types.path;
      description = ''
        Serial port device path for the Z-Wave controller.
        Prefer a stable /dev/serial/by-id/ path over /dev/ttyACM*.
      '';
      example = "/dev/serial/by-id/usb-Zooz_800_Z-Wave_Stick_533D004242-if00";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.zwave-js = {
        protocol = "ws";
      };

      # Network security keys (S0/S2 + Long Range). Delivered via systemd
      # LoadCredential, so they never enter the nix store.
      sops.secrets."zwave-js/secrets.json" = {
        sopsFile = ../../../../secrets/zwave-js.json;
        format = "json";
        key = "";
        restartUnits = ["zwave-js.service"];
      };

      services.zwave-js = {
        enable = true;
        inherit (config.links.zwave-js) port;
        inherit (cfg) serialPort;
        secretsConfigFile = config.sops.secrets."zwave-js/secrets.json".path;
      };

      # The upstream module uses DynamicUser which breaks impermanence
      # because systemd's dynamic user/group IDs don't match the static
      # UIDs that impermanence bind-mounts expect.
      systemd.services.zwave-js.serviceConfig.DynamicUser = lib.mkForce false;
      users.users.zwave-js = {
        isSystemUser = true;
        group = "zwave-js";
      };
      users.groups.zwave-js = {};

      # Note: connecting Home Assistant is done through the UI:
      # 1. Navigate to Settings > Devices & services
      # 2. Add the Z-Wave integration
      # 3. Uncheck "Use the Z-Wave JS Supervisor add-on"
      # 4. Server URL: ws://127.0.0.1:${config.links.zwave-js.portStr}
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      # /var/cache/zwave-js holds the network/node cache; losing it forces
      # a full re-interview of every device (battery nodes take days).
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/cache/zwave-js";
            user = "zwave-js";
            group = "zwave-js";
          }
        ];
      };
    })
  ];
}

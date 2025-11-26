{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.home-assistant;
  mqttCfg = cfg.mqtt;
in {
  options.rat.services.home-assistant.mqtt = {
    enable = options.mkEnableOption "MQTT integration for Home Assistant";

    username = options.mkOption {
      type = types.str;
      default = "homeassistant";
      description = "Username for Home Assistant MQTT authentication.";
    };

    aclRules = options.mkOption {
      type = types.listOf types.str;
      default = [
        "readwrite homeassistant/#"
        "read homeassistant/status"
      ];
      description = ''
        ACL rules for Home Assistant MQTT user.
        Default rules allow full access to homeassistant/* topics.
      '';
    };

    extraAclRules = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Additional ACL rules for Home Assistant MQTT user.
        Useful for integrations like zigbee2mqtt.
      '';
      example = [
        "readwrite zigbee2mqtt/#"
        "readwrite esphome/#"
      ];
    };
  };

  config = modules.mkIf (cfg.enable && mqttCfg.enable) {
    # Define SOPS secret for MQTT password
    # This reads the mqtt_password key from secrets/home-assistant.yaml
    sops.secrets."home-assistant/mqtt_password" = {
      sopsFile = ../../../../../secrets/home-assistant.yaml;
      key = "mqtt_password";
    };

    # Automatically enable and configure Mosquitto
    rat.services.mosquitto = {
      enable = true;
      users.${mqttCfg.username} = {
        passwordFile = config.sops.secrets."home-assistant/mqtt_password".path;
        acl = mqttCfg.aclRules ++ mqttCfg.extraAclRules;
      };
    };

    # Add MQTT component to Home Assistant
    rat.services.home-assistant.extraComponents = lib.mkAfter ["mqtt"];

    # Note: MQTT broker configuration must be done through the Home Assistant UI:
    # 1. Navigate to Settings > Devices & services
    # 2. Add MQTT integration
    # 3. Configure broker: 127.0.0.1, port: ${toString config.links.mosquitto.port}
    # 4. Username: ${mqttCfg.username}
    # 5. Password: Use the mqtt_password from secrets/home-assistant.yaml
    # 6. Enable discovery and configure birth/will messages as needed
    #
    # The MQTT integration no longer supports declarative YAML configuration
    # for broker settings in modern Home Assistant versions.
  };
}

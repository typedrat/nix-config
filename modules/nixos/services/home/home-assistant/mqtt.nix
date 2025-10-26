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

    passwordFile = options.mkOption {
      type = types.path;
      description = "Path to file containing the MQTT password for Home Assistant.";
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
    # Automatically enable and configure Mosquitto
    rat.services.mosquitto = {
      enable = true;
      users.${mqttCfg.username} = {
        inherit (mqttCfg) passwordFile;
        acl = mqttCfg.aclRules ++ mqttCfg.extraAclRules;
      };
    };

    # Add MQTT component to Home Assistant
    rat.services.home-assistant.extraComponents = lib.mkAfter ["mqtt"];

    # Add MQTT configuration to Home Assistant when declaratively configured
    # When cfg.config is null (UI-managed), MQTT should be configured through the UI
    rat.services.home-assistant.config = lib.mkIf (cfg.config != null) {
      mqtt = {
        broker = "127.0.0.1";
        port = config.links.mosquitto.port;
        username = mqttCfg.username;
        password = "!secret mqtt_password";
        discovery = true;
        birth_message = {
          topic = "homeassistant/status";
          payload = "online";
        };
        will_message = {
          topic = "homeassistant/status";
          payload = "offline";
        };
      };
    };

    # Note: When using declarative configuration (cfg.config != null),
    # the mqtt_password secret needs to be added to Home Assistant's secrets.yaml:
    # mqtt_password: <contents of mqttCfg.passwordFile>
  };
}

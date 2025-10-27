{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.home-assistant;
  mqttCfg = cfg.mqtt;
  haCfg = config.services.home-assistant;
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

    # Add MQTT configuration to Home Assistant
    # Note: The mqtt_password secret must be defined in secrets/home-assistant.yaml
    # Enabling MQTT integration will add declarative MQTT config
    rat.services.home-assistant.config.mqtt = {
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
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.home-assistant;
  impermanenceCfg = config.rat.impermanence;
in {
  imports = [
    ./authentik.nix
    ./mqtt.nix
  ];
  options.rat.services.home-assistant = {
    enable = options.mkEnableOption "Home Assistant";

    subdomain = options.mkOption {
      type = types.str;
      default = "home";
      description = "The subdomain for Home Assistant.";
    };

    extraComponents = options.mkOption {
      type = types.listOf types.str;
      default = [
        "analytics"
        "default_config"
        "met"
        "radio_browser"
      ];
      description = ''
        List of Home Assistant components to enable.
        See https://www.home-assistant.io/integrations/ for available integrations.
      '';
    };

    extraPackages = options.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = ps: [];
      defaultText = "ps: []";
      description = ''
        Extra Python packages to make available to Home Assistant.
        Useful for integrations that require additional dependencies.
      '';
      example = "ps: with ps; [ psycopg2 ]";
    };

    config = options.mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      description = ''
        Home Assistant configuration as a Nix attribute set.
        If null, the configuration will be managed through the UI.
        See https://www.home-assistant.io/docs/configuration/ for available options.
      '';
      example = {
        homeassistant = {
          name = "Home";
          unit_system = "metric";
          time_zone = "UTC";
        };
      };
    };

    customComponents = options.mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of custom Home Assistant component packages.";
    };

    customLovelaceModules = options.mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of custom Lovelace module packages.";
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for Home Assistant.";
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for Home Assistant.";
    };

    usePostgres = options.mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use PostgreSQL as the database backend for Home Assistant.
        When enabled, automatically configures PostgreSQL with a hass database and user.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.home-assistant = {
        protocol = "http";
      };

      services.home-assistant = {
        enable = true;
        inherit (cfg) extraComponents extraPackages customComponents customLovelaceModules;

        config =
          if cfg.config != null
          then
            cfg.config
            // {
              http = {
                server_host = "127.0.0.1";
                server_port = config.links.home-assistant.port;
                use_x_forwarded_for = cfg.enableTraefik;
                trusted_proxies = lib.optionals cfg.enableTraefik ["127.0.0.1" "::1"];
              };
            }
          else {
            default_config = {};
            http = {
              server_host = "127.0.0.1";
              server_port = config.links.home-assistant.port;
              use_x_forwarded_for = cfg.enableTraefik;
              trusted_proxies = lib.optionals cfg.enableTraefik ["127.0.0.1" "::1"];
            };
          };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [config.links.home-assistant.port];
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.home-assistant = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.home-assistant.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.home-assistant.configDir;
            user = "hass";
            group = "hass";
          }
        ];
      };
    })

    (modules.mkIf cfg.enable {
      # Define SOPS secret for Home Assistant secrets.yaml
      # The entire decrypted YAML file is placed as secrets.yaml
      sops.secrets."home-assistant/secrets.yaml" = {
        sopsFile = ../../../../secrets/home-assistant.yaml;
        format = "binary";
        owner = "hass";
        group = "hass";
        mode = "0440";
        path = "${config.services.home-assistant.configDir}/secrets.yaml";
      };

      # Ensure home-assistant service restarts when secrets change
      systemd.services.home-assistant = {
        restartTriggers = [
          config.sops.secrets."home-assistant/secrets.yaml".path
        ];
      };
    })

    (modules.mkIf (cfg.enable && cfg.usePostgres) {
      # Add PostgreSQL support
      rat.services.home-assistant.extraPackages = lib.mkAfter (ps: with ps; [psycopg2]);

      # Configure recorder to use PostgreSQL
      rat.services.home-assistant.config = lib.mkIf (cfg.config != null) {
        recorder = {
          db_url = "postgresql://@/hass";
        };
      };

      # Enable and configure PostgreSQL
      services.postgresql = {
        enable = true;
        ensureDatabases = ["hass"];
        ensureUsers = [
          {
            name = "hass";
            ensureDBOwnership = true;
          }
        ];
      };
    })
  ];
}

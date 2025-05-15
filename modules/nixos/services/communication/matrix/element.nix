{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) attrsets modules options types;
  inherit (config.rat.services) domainName;
  cfg = config.rat.services.element;
  synapseCfg = config.rat.services.matrix-synapse;

  catppuccinCfg = builtins.fromJSON (builtins.readFile "${inputs.catppuccin-element}/config.json");

  configuredPackage =
    (cfg.package.override {
      conf = attrsets.mergeAttrsList [
        {
          default_server_config."m.homeserver" = {
            base_url = config.services.matrix-synapse.settings.public_baseurl;
            inherit (config.services.matrix-synapse.settings) server_name;
          };
          disable_custom_urls = true;
          default_theme = cfg.defaultTheme;
          room_directory.servers = [domainName];
        }

        catppuccinCfg

        (modules.mkIf cfg.enableAdvancedFeatures {
          features = {
            feature_ask_to_join = true;
            feature_bridge_state = true;
            feature_jump_to_date = true;
            feature_mjolnir = true;
            feature_notifications = true;
            feature_pinning = true;
            feature_report_to_moderators = true;
            feature_thread = true;
            feature_wysiwyg_composer = true;
            feature_hidebold = true;
          };
          show_labs_settings = true;
        })

        cfg.extraConfig
      ];
    }).overrideAttrs ({postInstall ? "", ...}: {
      # Prevent 404 spam in nginx log
      postInstall =
        postInstall
        + ''
          ln -rs $out/config.json $out/config.${cfg.subdomain}.${domainName}.json
        '';
    });
in {
  options.rat.services.element = {
    enable = options.mkEnableOption "Element Web, a Matrix client";
    subdomain = options.mkOption {
      type = types.str;
      default = "element";
      description = "The subdomain to use for Element Web";
    };
    package = options.mkPackageOption pkgs "element-web" {};

    enableAdvancedFeatures = options.mkEnableOption "advanced and lab features in Element Web";

    defaultHomeserver = options.mkOption {
      type = types.str;
      default = "${config.rat.services.matrix-synapse.subdomain}.${domainName}";
      description = "Default homeserver URL to connect to";
    };

    defaultTheme = options.mkOption {
      type = types.str;
      default = "dark";
      description = "Default theme for Element Web (light or dark)";
    };

    extraConfig = options.mkOption {
      type = types.attrs;
      default = {};
      description = "Additional configuration to merge into element-web's config.json";
    };
  };

  config = modules.mkIf cfg.enable {
    links = {
      element-web = {
        protocol = "http";
      };
    };

    services.traefik.dynamicConfigOptions = lib.mkIf synapseCfg.enable {
      http.middlewares.matrix-to-element-redirect = {
        redirectRegex = {
          regex = "^https://${synapseCfg.subdomain}.${domainName}/?$";
          replacement = "https://${cfg.subdomain}.${domainName}/";
          permanent = false;
        };
      };
    };

    rat.services.traefik = {
      routes = {
        element-web = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.element-web.url;
        };

        matrix-synapse = modules.mkIf synapseCfg.enable {
          extraMiddlewares = ["matrix-to-element-redirect"];
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.element-web = {
        listen = [
          {
            addr = config.links.element-web.ipv4;
            inherit (config.links.element-web) port;
          }
        ];

        root = configuredPackage;
      };
    };

    services.matrix-synapse = lib.mkIf synapseCfg.enable {
      settings = {
        web_client_location = "https://${cfg.subdomain}.${domainName}";
      };
    };
  };
}

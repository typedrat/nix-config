{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.grafana;
  impermanenceCfg = config.rat.impermanence;
  authentikCfg = config.rat.services.authentik;

  inherit (config.rat.services) domainName;
in {
  options.rat.services.grafana = {
    enable = options.mkEnableOption "Grafana";
    subdomain = options.mkOption {
      type = types.str;
      default = "grafana";
      description = "The subdomain for Grafana.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.grafana = {
        enable = true;

        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = config.links.grafana.port;
            enforce_domain = true;
            enable_gzip = true;
            domain = "${cfg.subdomain}.${domainName}";
            root_url = "https://${cfg.subdomain}.${domainName}";
          };

          database = {
            type = "postgres";
            host = "/run/postgresql";
            user = "grafana";
          };

          remote_cache = {
            type = "redis";
            connstr = "addr=${config.links.grafana-redis.tuple}";
          };

          analytics.reporting_enabled = false;

          security = {
            disable_initial_admin_creation = true;
            cookie_secure = true;
          };

          users = {
            default_theme = "system";
          };

          auth = {
            oauth_auto_login = true;
            signout_redirect_url = "https://${authentikCfg.subdomain}.${domainName}/application/o/grafana/end-session/";
          };

          "auth.basic" = {
            enabled = false;
          };

          "auth.generic_oauth" = let
            role_attribute_path = lib.concatStringsSep " || " [
              "contains(entitlements, 'Grafana Administrator') && 'Admin'"
              "contains(entitlements, 'Grafana Editor') && 'Editor'"
              "Viewer"
            ];
          in {
            enabled = true;
            name = "authentik";
            client_id = "$__file{${config.sops.secrets."grafana/oauth_client_id".path}}";
            client_secret = "$__file{${config.sops.secrets."grafana/oauth_client_secret".path}}";
            scopes = ["openid" "profile" "email" "entitlements"];
            auth_url = "https://${authentikCfg.subdomain}.${domainName}/application/o/authorize/";
            token_url = "https://${authentikCfg.subdomain}.${domainName}/application/o/token/";
            api_url = "https://${authentikCfg.subdomain}.${domainName}/application/o/userinfo/";
            role_attribute_path = "\"${role_attribute_path}\"";
          };
        };

        provision = {
          enable = true;

          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = config.links.prometheus.url;
            }
            {
              name = "Loki";
              type = "loki";
              url = config.links.loki.url;
            }
          ];
        };
      };

      systemd.services.grafana = {
        after = ["postgresql.service" "redis-grafana.service"];
      };

      rat.services.traefik.routes.grafana = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.grafana.url;
      };

      services.postgresql = {
        ensureUsers = [
          {
            name = "grafana";
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = ["grafana"];
      };

      services.redis.servers.grafana = {
        enable = true;
        group = "grafana";
        inherit (config.links.grafana-redis) port;
      };

      sops.secrets = {
        "grafana/oauth_client_id" = {
          sopsFile = ../../../../secrets/grafana.yaml;
          key = "clientId";
          owner = config.systemd.services.grafana.serviceConfig.User;
        };
        "grafana/oauth_client_secret" = {
          sopsFile = ../../../../secrets/grafana.yaml;
          key = "clientSecret";
          owner = config.systemd.services.grafana.serviceConfig.User;
        };
      };

      links = {
        grafana = {
          protocol = "http";
        };

        grafana-redis = {
          protocol = "redis";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.grafana.dataDir;
            user = "grafana";
            group = "grafana";
          }
        ];
      };
    })
  ];
}

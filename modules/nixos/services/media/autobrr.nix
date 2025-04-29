{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.autobrr;
  impermanenceCfg = config.rat.impermanence;
  authentikCfg = config.rat.services.authentik;

  inherit (config.rat.services) domainName;

  mkAutobrrSecrets = path: secrets:
    builtins.listToAttrs (builtins.map (secret: {
        name = "autobrr/${secret}";
        value = {
          sopsFile = path;
          key = secret;
          owner = "autobrr";
          group = "autobrr";
          mode = "0700";
        };
      })
      secrets);
in {
  options.rat.services.autobrr = {
    enable = options.mkEnableOption "autobrr";
    subdomain = options.mkOption {
      type = types.str;
      default = "autobrr";
      description = "The subdomain for autobrr.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      systemd.services.autobrr = {
        description = "Autobrr";
        after = [
          "postgresql.service"
          "syslog.target"
          "network-online.target"
        ];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "simple";
          User = "autobrr";
          Group = "autobrr";
          StateDirectory = "autobrr";
          ExecStart = "${lib.getExe pkgs.autobrr} --config /var/lib/autobrr";
          Restart = "on-failure";
        };
      };

      sops.templates."autobrr.toml" = {
        content = inputs.nix-std.lib.serde.toTOML {
          host = config.links.autobrr.ipv4;
          port = config.links.autobrr.port;
          checkForUpdates = false;
          sessionSecret = config.sops.placeholder."autobrr/sessionSecret";

          oidcEnabled = true;
          oidcIssuer = "https://${authentikCfg.subdomain}.${domainName}/application/o/autobrr/";
          oidcClientId = config.sops.placeholder."autobrr/clientId";
          oidcClientSecret = config.sops.placeholder."autobrr/clientSecret";
          oidcRedirectUrl = "https://${cfg.subdomain}.${domainName}/api/auth/oidc/callback";
          oidcDisableBuiltInLogin = true;

          metricsEnabled = true;
          metricsHost = config.links.autobrr-metrics.ipv4;
          metricsPort = config.links.autobrr-metrics.port;

          # Database type (sqlite/postgres)
          databaseType = "postgres";

          # Postgres specific settings
          postgresHost = config.links.postgres.ipv4;
          postgresPort = config.links.postgres.port;
          postgresDatabase = "autobrr";
          postgresUser = "autobrr";
          postgresPass = config.sops.placeholder."autobrr/db/password";
          postgresSSLMode = "disable";
        };
        path = "/var/lib/autobrr/config.toml";
        owner = "autobrr";
        group = "autobrr";
        mode = "0600";
        restartUnits = ["autobrr.service"];
      };

      sops.secrets = modules.mkMerge [
        (mkAutobrrSecrets ../../../../secrets/autobrr.yaml [
          "sessionSecret"
          "clientId"
          "clientSecret"
        ])
        {
          "autobrr/db/password" = {
            sopsFile = ../../../../secrets/autobrr.yaml;
            key = "db/password";
            owner = "postgres";
            group = "postgres";
            mode = "0700";
          };
        }
      ];

      rat.services.postgres = {
        enable = true;

        users = {
          autobrr = {
            passwordFile = config.sops.secrets."autobrr/db/password".path;
            ownedDatabases = ["autobrr"];
          };
        };
      };

      links = {
        autobrr = {
          protocol = "http";
        };
        autobrr-metrics = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.autobrr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.autobrr.url;
      };

      users = {
        users.autobrr = {
          isSystemUser = true;
          home = "/var/lib/autobrr";
          createHome = true;
          group = "autobrr";
        };

        groups.autobrr = {};
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/autobrr";
            user = "autobrr";
            group = "autobrr";
          }
        ];
      };
    })
  ];
}

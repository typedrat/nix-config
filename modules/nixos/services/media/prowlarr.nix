{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.prowlarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.prowlarr = {
    enable = options.mkEnableOption "Prowlarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "prowlarr";
      description = "The subdomain for Prowlarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.prowlarr = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.prowlarr.port;

          postgres = {
            host = "localhost";
            port = config.links.postgres.port;
            user = "prowlarr";
            maindb = "prowlarr";
            logdb = "prowlarr-log";
          };
        };

        environmentFiles = [
          config.sops.templates."prowlarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          prowlarr = {
            passwordFile = config.sops.secrets."prowlarr/db/password".path;
            ownedDatabases = ["prowlarr" "prowlarr-log"];
          };
        };
      };

      sops.secrets."prowlarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "prowlarr/db/password";
        restartUnits = ["postgresql.service" "prowlarr.service"];
        owner = "postgres";
      };

      sops.secrets."prowlarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "prowlarr/apiKey";
        restartUnits = ["prowlarr.service"];
      };

      sops.templates."prowlarr.env" = {
        content = lib.toShellVars {
          PROWLARR__AUTH__APIKEY = "${config.sops.placeholder."prowlarr/apiKey"}";
          PROWLARR__POSTGRES__PASSWORD = "${config.sops.placeholder."prowlarr/db/password"}";
        };

        restartUnits = ["prowlarr.service"];
      };

      links.prowlarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.prowlarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.prowlarr.url;

        authentik = true;
        theme-park.app = "prowlarr";
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users = {
        users.prowlarr = {
          isSystemUser = true;
          home = "/var/lib/prowlarr";
          createHome = true;
          group = "prowlarr";
        };
        groups.prowlarr = {};
      };

      systemd.services.prowlarr = {
        after = ["postgresql.service"];
        serviceConfig = {
          DynamicUser = modules.mkForce false;
          User = "prowlarr";
          Group = "prowlarr";
        };
      };

      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/prowlarr";
          user = "prowlarr";
          group = "prowlarr";
        }
      ];
    })
  ];
}

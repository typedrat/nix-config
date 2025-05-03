{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.sonarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.sonarr = {
    enable = options.mkEnableOption "Sonarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "sonarr";
      description = "The subdomain for Sonarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.sonarr.instances.default = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.sonarr.port;

          postgres = {
            host = "localhost";
            port = config.links.postgres.port;
            user = "sonarr";
            maindb = "sonarr";
            logdb = "sonarr-log";
          };
        };

        environmentFiles = [
          config.sops.templates."sonarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          sonarr = {
            passwordFile = config.sops.secrets."sonarr/db/password".path;
            ownedDatabases = ["sonarr" "sonarr-log"];
          };
        };
      };

      systemd.services.sonarr-default = {
        after = ["postgresql.service"];
      };

      users.users.sonarr-default.extraGroups = ["media"];

      sops.secrets."sonarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "sonarr/db/password";
        restartUnits = ["postgresql.service" "sonarr-default.service"];
        owner = "postgres";
      };

      sops.secrets."sonarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "sonarr/apiKey";
        restartUnits = ["sonarr-default.service"];
      };

      sops.templates."sonarr.env" = {
        content = lib.toShellVars {
          SONARR__AUTH__APIKEY = "${config.sops.placeholder."sonarr/apiKey"}";
          SONARR__POSTGRES__PASSWORD = "${config.sops.placeholder."sonarr/db/password"}";
        };

        restartUnits = ["sonarr-default.service"];
      };

      links.sonarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.sonarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.sonarr.url;

        authentik = true;
        theme-park = {
          app = "sonarr";
          target = "</body>";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/sonarr-default";
          user = "sonarr-default";
          group = "sonarr-default";
        }
      ];
    })
  ];
}

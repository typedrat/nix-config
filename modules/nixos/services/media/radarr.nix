{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.radarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.radarr = {
    enable = options.mkEnableOption "Radarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "radarr";
      description = "The subdomain for Radarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.radarr.instances.default = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.radarr.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "radarr";
            maindb = "radarr";
            logdb = "radarr-log";
          };
        };

        environmentFiles = [
          config.sops.templates."radarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          radarr = {
            passwordFile = config.sops.secrets."radarr/db/password".path;
            ownedDatabases = ["radarr" "radarr-log"];
          };
        };
      };

      systemd.services.radarr-default = {
        after = ["postgresql.service"];
      };

      users.users.radarr-default.extraGroups = ["media"];

      sops.secrets."radarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "radarr/db/password";
        restartUnits = ["postgresql.service" "radarr-default.service"];
        owner = "postgres";
      };

      sops.secrets."radarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "radarr/apiKey";
        restartUnits = ["radarr-default.service"];
      };

      sops.templates."radarr.env" = {
        content = lib.toShellVars {
          RADARR__AUTH__APIKEY = "${config.sops.placeholder."radarr/apiKey"}";
          RADARR__POSTGRES__PASSWORD = "${config.sops.placeholder."radarr/db/password"}";
        };

        restartUnits = ["radarr-default.service"];
      };

      links.radarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.radarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.radarr.url;

        authentik = true;
        theme-park = {
          app = "radarr";
          target = "</body>";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/radarr-default";
          user = "radarr-default";
          group = "radarr-default";
        }
      ];
    })
  ];
}

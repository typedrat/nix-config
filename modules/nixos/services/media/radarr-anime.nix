{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.radarr.anime;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.radarr.anime = {
    enable = options.mkEnableOption "Radarr (Anime)";
    subdomain = options.mkOption {
      type = types.str;
      default = "radarr-anime";
      description = "The subdomain for the anime-specialized instance of Radarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.radarr.instances.anime = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.radarr-anime.port;

          postgres = {
            host = "localhost";
            port = config.links.postgres.port;
            user = "radarr-anime";
            maindb = "radarr-anime";
            logdb = "radarr-anime-log";
          };
        };

        environmentFiles = [
          config.sops.templates."radarr-anime.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          radarr-anime = {
            passwordFile = config.sops.secrets."radarr-anime/db/password".path;
            ownedDatabases = ["radarr-anime" "radarr-anime-log"];
          };
        };
      };

      systemd.services.radarr-anime = {
        after = ["postgresql.service"];
        serviceConfig = {
          SupplementalGroups = ["media"];
        };
      };

      sops.secrets."radarr-anime/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "radarr-anime/db/password";
        restartUnits = ["postgresql.service" "radarr-anime.service"];
        owner = "postgres";
      };

      sops.secrets."radarr-anime/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "radarr-anime/apiKey";
        restartUnits = ["radarr-anime.service"];
      };

      sops.templates."radarr-anime.env" = {
        content = lib.toShellVars {
          RADARR__AUTH__APIKEY = "${config.sops.placeholder."radarr-anime/apiKey"}";
          RADARR__POSTGRES__PASSWORD = "${config.sops.placeholder."radarr-anime/db/password"}";
        };

        restartUnits = ["radarr-anime.service"];
      };

      links.radarr-anime = {
        protocol = "http";
      };

      rat.services.traefik.routes.radarr-anime = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.radarr-anime.url;

        authentik = true;
        theme-park = {
          app = "radarr";
          addons = [
            "radarr-anime-text-logo"
            "radarr-anime-favicon"
          ];
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/radarr-anime";
          user = "radarr-anime";
          group = "radarr-anime";
        }
      ];
    })
  ];
}

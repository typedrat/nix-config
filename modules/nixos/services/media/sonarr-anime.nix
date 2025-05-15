{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.sonarr.anime;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.sonarr.anime = {
    enable = options.mkEnableOption "Sonarr (Anime)";
    subdomain = options.mkOption {
      type = types.str;
      default = "sonarr-anime";
      description = "The subdomain for the anime-specialized instance of Sonarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.sonarr.instances.anime = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.sonarr-anime.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "sonarr-anime";
            maindb = "sonarr-anime";
            logdb = "sonarr-anime-log";
          };
        };

        environmentFiles = [
          config.sops.templates."sonarr-anime.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          sonarr-anime = {
            passwordFile = config.sops.secrets."sonarr-anime/db/password".path;
            ownedDatabases = ["sonarr-anime" "sonarr-anime-log"];
          };
        };
      };

      systemd.services.sonarr-anime = {
        after = ["postgresql.service"];
      };

      users.users.sonarr-anime.extraGroups = ["media"];

      sops.secrets."sonarr-anime/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "sonarr-anime/db/password";
        restartUnits = ["postgresql.service" "sonarr-anime.service"];
        owner = "postgres";
      };

      sops.secrets."sonarr-anime/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "sonarr-anime/apiKey";
        restartUnits = ["sonarr-anime.service"];
      };

      sops.templates."sonarr-anime.env" = {
        content = lib.toShellVars {
          SONARR__AUTH__APIKEY = "${config.sops.placeholder."sonarr-anime/apiKey"}";
          SONARR__POSTGRES__PASSWORD = "${config.sops.placeholder."sonarr-anime/db/password"}";
        };

        restartUnits = ["sonarr-anime.service"];
      };

      links.sonarr-anime = {
        protocol = "http";
      };

      rat.services.traefik.routes.sonarr-anime = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.sonarr-anime.url;

        authentik = true;
        theme-park = {
          app = "sonarr";
          target = "</body>";
          addons = [
            "sonarr-anime-text-logo"
            "sonarr-anime-favicon"
          ];
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/sonarr-anime";
          user = "sonarr-anime";
          group = "sonarr-anime";
        }
      ];
    })
  ];
}

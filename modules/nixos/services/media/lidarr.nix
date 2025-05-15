{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.lidarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.lidarr = {
    enable = options.mkEnableOption "Lidarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "lidarr";
      description = "The subdomain for Lidarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.lidarr.instances.default = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.lidarr.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "lidarr";
            maindb = "lidarr";
            logdb = "lidarr-log";
          };
        };

        environmentFiles = [
          config.sops.templates."lidarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          lidarr = {
            passwordFile = config.sops.secrets."lidarr/db/password".path;
            ownedDatabases = ["lidarr" "lidarr-log"];
          };
        };
      };

      systemd.services.lidarr-default = {
        after = ["postgresql.service"];
      };

      users.users.lidarr-default.extraGroups = ["media"];

      sops.secrets."lidarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "lidarr/db/password";
        restartUnits = ["postgresql.service" "lidarr-default.service"];
        owner = "postgres";
      };

      sops.secrets."lidarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "lidarr/apiKey";
        restartUnits = ["lidarr-default.service"];
      };

      sops.templates."lidarr.env" = {
        content = lib.toShellVars {
          LIDARR__AUTH__APIKEY = "${config.sops.placeholder."lidarr/apiKey"}";
          LIDARR__POSTGRES__PASSWORD = "${config.sops.placeholder."lidarr/db/password"}";
        };

        restartUnits = ["lidarr-default.service"];
      };

      links.lidarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.lidarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.lidarr.url;

        authentik = true;
        theme-park.app = "lidarr";
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/lidarr-default";
          user = "lidarr-default";
          group = "lidarr-default";
        }
      ];
    })
  ];
}

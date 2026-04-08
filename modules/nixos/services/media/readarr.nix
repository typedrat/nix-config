{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.readarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.readarr = {
    enable = options.mkEnableOption "Readarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "readarr";
      description = "The subdomain for Readarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.readarr.instances.default = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.readarr.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "readarr";
            maindb = "readarr";
            logdb = "readarr-log";
            cachedb = "readarr-cache";
          };
        };

        environmentFiles = [
          config.sops.templates."readarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          readarr = {
            passwordFile = config.sops.secrets."readarr/db/password".path;
            ownedDatabases = ["readarr" "readarr-log" "readarr-cache"];
          };
        };
      };

      systemd.services.readarr-default = {
        after = ["postgresql.service"];
      };

      users.users.readarr-default.extraGroups = ["media"];

      sops.secrets."readarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "readarr/db/password";
        restartUnits = ["postgresql.service" "readarr-default.service"];
        owner = "postgres";
      };

      sops.secrets."readarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "readarr/apiKey";
        restartUnits = ["readarr-default.service"];
      };

      sops.templates."readarr.env" = {
        content = lib.toShellVars {
          READARR__AUTH__APIKEY = "${config.sops.placeholder."readarr/apiKey"}";
          READARR__POSTGRES__PASSWORD = "${config.sops.placeholder."readarr/db/password"}";
        };

        restartUnits = ["readarr-default.service"];
      };

      links.readarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.readarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.readarr.url;

        authentik = true;
        theme-park = {
          app = "readarr";
          target = "</body>";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/readarr-default";
          user = "readarr-default";
          group = "readarr-default";
        }
      ];
    })
  ];
}

{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.chaptarr;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.chaptarr = {
    enable = options.mkEnableOption "Chaptarr";
    subdomain = options.mkOption {
      type = types.str;
      default = "chaptarr";
      description = "The subdomain for Chaptarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.readarr.instances.default = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.chaptarr.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "chaptarr";
            maindb = "chaptarr";
            logdb = "chaptarr-log";
            cachedb = "chaptarr-cache";
          };
        };

        environmentFiles = [
          config.sops.templates."chaptarr.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          chaptarr = {
            passwordFile = config.sops.secrets."chaptarr/db/password".path;
            ownedDatabases = ["chaptarr" "chaptarr-log" "chaptarr-cache"];
          };
        };
      };

      systemd.services.readarr-default = {
        after = ["postgresql.service"];
      };

      users.users.readarr-default.extraGroups = ["media"];

      sops.secrets."chaptarr/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "chaptarr/db/password";
        restartUnits = ["postgresql.service" "readarr-default.service"];
        owner = "postgres";
      };

      sops.secrets."chaptarr/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "chaptarr/apiKey";
        restartUnits = ["readarr-default.service"];
      };

      sops.templates."chaptarr.env" = {
        content = lib.toShellVars {
          CHAPTARR__AUTH__APIKEY = "${config.sops.placeholder."chaptarr/apiKey"}";
          CHAPTARR__POSTGRES__PASSWORD = "${config.sops.placeholder."chaptarr/db/password"}";
        };

        restartUnits = ["readarr-default.service"];
      };

      links.chaptarr = {
        protocol = "http";
      };

      rat.services.traefik.routes.chaptarr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.chaptarr.url;

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

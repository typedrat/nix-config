{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.readarr.audiobooks;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.readarr.audiobooks = {
    enable = options.mkEnableOption "Readarr (Audiobooks)";
    subdomain = options.mkOption {
      type = types.str;
      default = "readarr-audiobooks";
      description = "The subdomain for the audiobook-specialized instance of Readarr";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.readarr.instances.audiobooks = {
        enable = true;
        settings = {
          auth.method = "External";

          server.port = config.links.readarr-audiobooks.port;

          postgres = {
            host = "localhost";
            inherit (config.links.postgres) port;
            user = "readarr-audiobooks";
            maindb = "readarr-audiobooks";
            logdb = "readarr-audiobooks-log";
            cachedb = "readarr-audiobooks-cache";
          };
        };

        environmentFiles = [
          config.sops.templates."readarr-audiobooks.env".path
        ];
      };

      rat.services.postgres = {
        enable = true;

        users = {
          readarr-audiobooks = {
            passwordFile = config.sops.secrets."readarr-audiobooks/db/password".path;
            ownedDatabases = ["readarr-audiobooks" "readarr-audiobooks-log" "readarr-audiobooks-cache"];
          };
        };
      };

      systemd.services.readarr-audiobooks = {
        after = ["postgresql.service"];
      };

      users.users.readarr-audiobooks.extraGroups = ["media"];

      sops.secrets."readarr-audiobooks/db/password" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "readarr-audiobooks/db/password";
        restartUnits = ["postgresql.service" "readarr-audiobooks.service"];
        owner = "postgres";
      };

      sops.secrets."readarr-audiobooks/apiKey" = {
        sopsFile = ../../../../secrets/arrs.yaml;
        key = "readarr-audiobooks/apiKey";
        restartUnits = ["readarr-audiobooks.service"];
      };

      sops.templates."readarr-audiobooks.env" = {
        content = lib.toShellVars {
          READARR__AUTH__APIKEY = "${config.sops.placeholder."readarr-audiobooks/apiKey"}";
          READARR__POSTGRES__PASSWORD = "${config.sops.placeholder."readarr-audiobooks/db/password"}";
        };

        restartUnits = ["readarr-audiobooks.service"];
      };

      links.readarr-audiobooks = {
        protocol = "http";
      };

      rat.services.traefik.routes.readarr-audiobooks = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.readarr-audiobooks.url;

        authentik = true;
        theme-park = {
          app = "readarr";
          target = "</body>";

          addons = [
            "readarr-audiobooks-text-logo"
            "readarr-audiobooks-favicon"
          ];
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/readarr-audiobooks";
          user = "readarr-audiobooks";
          group = "readarr-audiobooks";
        }
      ];
    })
  ];
}

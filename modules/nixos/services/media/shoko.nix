{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.shoko;
  impermanenceCfg = config.rat.impermanence;

  persistentGroup = "shoko-persist";

  mysqlSocket = "/run/mysqld/mysqld.sock";
  mkMysqlConnStr = db: "Server=${mysqlSocket};Database=${db};User Id=shoko;Password=;ConnectionProtocol=Unix;SslMode=None;AllowUserVariables=true;CharSet=utf8mb4";

  stateDir = "/var/lib/shoko";

  # Settings Shoko reads from the environment at load. Unless a setting allows
  # an override, a value given here also locks it against edits from the API
  # and the web UI.
  environment = {
    DB_TYPE = "MySQL";
    DB_HOST = "localhost";
    DB_USER = "shoko";
    DB_NAME = "shoko";
    DB_CONNECTION_STRING = mkMysqlConnStr "shoko";
    DB_BACKUP_DIRECTORY = "${stateDir}/DatabaseBackup";
    DB_SQLITE_DIRECTORY = "${stateDir}/SQLite";

    SHOKO_PORT = toString config.links.shoko.port;
    SHOKO_FIRST_RUN = "false";

    # The released plugins ship inside the package; letting Shoko upgrade them
    # would install newer copies beside it in the data directory.
    SHOKO_PLUGIN_AUTO_UPGRADE_ENABLED = "false";
    SHOKO_PLUGIN_UPGRADE_ON_START_ENABLED = "false";
  };
in {
  options.rat.services.shoko = {
    enable = options.mkEnableOption "Shoko";
    subdomain = options.mkOption {
      type = types.str;
      default = "shoko";
      description = "The subdomain for Shoko";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      rat.services.mysql.enable = true;

      # The server and web UI come from packages/, which track the daily dev
      # builds and override nixpkgs' stable shoko and shoko-webui.
      services.shoko.enable = true;

      systemd.services.shoko = {
        after = ["mysql.service" "network-online.target"];
        wants = ["network-online.target"];
        inherit environment;
        preStart = modules.mkAfter ''
          mkdir -p /var/lib/shoko/themes
          ln -sf ${inputs.catppuccin-shoko-webui}/themes/*/* /var/lib/shoko/themes/

          # Update AniDB HTTP cache on each start without overwriting existing
          # files. It only saves AniDB requests, so a failed download must not
          # keep Shoko from starting.
          echo "Updating AniDB HTTP cache..."
          if ${pkgs.curl}/bin/curl -fsSL --retry 3 -o /tmp/Anime_HTTP.zip \
            "https://files.shokoanime.com/files/shoko-server/other/Anime_HTTP.zip"; then
            mkdir -p "$STATE_DIRECTORY/Anime_HTTP"
            # Zip contains a nested Anime_HTTP/ directory — extract to temp then move
            ${pkgs.unzip}/bin/unzip -n -q /tmp/Anime_HTTP.zip -d /tmp/Anime_HTTP_extract
            mv -n /tmp/Anime_HTTP_extract/Anime_HTTP/* "$STATE_DIRECTORY/Anime_HTTP/" 2>/dev/null || true
          else
            echo "warning: could not download the AniDB HTTP cache; starting with the existing one" >&2
          fi
          rm -rf /tmp/Anime_HTTP.zip /tmp/Anime_HTTP_extract
        '';
        serviceConfig.ExtraGroups = ["media" "mysql" persistentGroup];
      };

      services.mysql = {
        ensureDatabases = [
          "shoko"
        ];

        ensureUsers = [
          {
            name = "shoko";
            ensurePermissions = {
              "shoko.*" = "ALL PRIVILEGES";
            };
          }
        ];
      };

      links.shoko = {
        protocol = "http";
        port = 8111;
      };

      rat.services.traefik.routes.shoko = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.shoko.url;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users = {
        users.shoko = {
          isSystemUser = true;
          home = "/var/lib/shoko";
          createHome = true;
          group = "shoko";
        };

        groups.shoko = {};
      };

      systemd.services.shoko = {
        serviceConfig = {
          DynamicUser = modules.mkForce false;
          User = "shoko";
          Group = "shoko";
          SupplementaryGroups = ["media"];
        };
      };

      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/shoko";
          user = "shoko";
          group = "shoko";
        }
      ];
    })
  ];
}

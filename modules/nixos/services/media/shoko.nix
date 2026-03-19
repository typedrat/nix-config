{
  config,
  inputs',
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

  defaultSettings = builtins.toJSON {
    "$schema" = "file:///var/lib/shoko/settings-server.schema.json";
    SettingsVersion = 12;
    FirstRun = true;
    Database = {
      Type = "MySQL";
      Host = "localhost";
      Username = "shoko";
      Password = "";
      Schema = "shoko";
      OverrideConnectionString = mkMysqlConnStr "shoko";
      DatabaseBackupDirectory = "/var/lib/shoko/DatabaseBackup";
      UseDatabaseLock = true;
    };
    Quartz = {
      DatabaseType = "SQLite";
      ConnectionString = "Data Source=/var/lib/shoko/SQLite/Quartz.db3;Mode=ReadWriteCreate;Pooling=True";
    };
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

      services.shoko = {
        enable = true;
        package = inputs'.nanopkgs.packages.shoko;
        webui = inputs'.nanopkgs.packages.shoko-webui;
      };

      systemd.services.shoko = {
        after = ["mysql.service"];
        preStart = modules.mkAfter ''
          mkdir -p /var/lib/shoko/themes
          ln -sf ${inputs.catppuccin-shoko-webui}/themes/*/* /var/lib/shoko/themes/

          # Seed MySQL database settings on first run
          if [ ! -f "$STATE_DIRECTORY/settings-server.json" ] || \
             ${pkgs.jq}/bin/jq -e '.Database.Type == "SQLite"' "$STATE_DIRECTORY/settings-server.json" > /dev/null 2>&1; then
            if [ -f "$STATE_DIRECTORY/settings-server.json" ]; then
              # Existing config but with SQLite — patch to MySQL, preserving other settings
              ${pkgs.jq}/bin/jq '
                .Database.Type = "MySQL" |
                .Database.Host = "localhost" |
                .Database.Username = "shoko" |
                .Database.Password = "" |
                .Database.Schema = "shoko" |
                .Database.OverrideConnectionString = ${builtins.toJSON (mkMysqlConnStr "shoko")} |
                .Quartz.DatabaseType = "SQLite" |
                .Quartz.ConnectionString = "Data Source=/var/lib/shoko/SQLite/Quartz.db3;Mode=ReadWriteCreate;Pooling=True"
              ' "$STATE_DIRECTORY/settings-server.json" > "$STATE_DIRECTORY/settings-server.json.tmp"
              mv "$STATE_DIRECTORY/settings-server.json.tmp" "$STATE_DIRECTORY/settings-server.json"
            else
              # No config yet — write default settings
              cat ${pkgs.writeText "shoko-default-settings.json" defaultSettings} > "$STATE_DIRECTORY/settings-server.json"
            fi
          fi

          # Update AniDB HTTP cache on each start without overwriting existing files
          echo "Updating AniDB HTTP cache..."
          ${pkgs.curl}/bin/curl -fsSL -o /tmp/Anime_HTTP.zip \
            "https://files.shokoanime.com/files/shoko-server/other/Anime_HTTP.zip"
          mkdir -p "$STATE_DIRECTORY/Anime_HTTP"
          # Zip contains a nested Anime_HTTP/ directory — extract to temp then move
          ${pkgs.unzip}/bin/unzip -n -q /tmp/Anime_HTTP.zip -d /tmp/Anime_HTTP_extract
          mv -n /tmp/Anime_HTTP_extract/Anime_HTTP/* "$STATE_DIRECTORY/Anime_HTTP/" 2>/dev/null || true
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

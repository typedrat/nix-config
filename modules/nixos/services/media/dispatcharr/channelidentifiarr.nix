{
  config,
  lib,
  pkgs,
  self',
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.channelidentifiarr;
  impermanenceCfg = config.rat.impermanence;

  stateDir = "/var/lib/channelidentifiarr";
  databasePath = "${stateDir}/channelidentifiarr.db";
  etagPath = "${stateDir}/.database-etag";
  databaseUrl = "https://epg.jesmann.com/channelidentifiarr.db";

  inherit (self'.packages) channelidentifiarr;

  updateScript = pkgs.writeShellScript "channelidentifiarr-update-db" ''
    set -euo pipefail

    ETAG_FILE="${etagPath}"
    DB_FILE="${databasePath}"
    DB_URL="${databaseUrl}"

    # Get current ETag if it exists
    CURRENT_ETAG=""
    if [[ -f "$ETAG_FILE" ]]; then
      CURRENT_ETAG=$(cat "$ETAG_FILE")
    fi

    # Check remote ETag with a HEAD request
    echo "Checking for database updates..."
    HEADERS=$(${pkgs.curl}/bin/curl -sI "$DB_URL")
    REMOTE_ETAG=$(echo "$HEADERS" | grep -i '^etag:' | tr -d '\r' | cut -d' ' -f2-)

    if [[ -z "$REMOTE_ETAG" ]]; then
      echo "Warning: No ETag received from server, proceeding with download"
    elif [[ "$CURRENT_ETAG" == "$REMOTE_ETAG" ]]; then
      echo "Database is up to date (ETag: $CURRENT_ETAG)"
      exit 0
    fi

    echo "New database available, downloading..."
    echo "Current ETag: $CURRENT_ETAG"
    echo "Remote ETag: $REMOTE_ETAG"

    # Stop the service before updating
    echo "Stopping channelidentifiarr service..."
    ${pkgs.systemd}/bin/systemctl stop channelidentifiarr.service || true

    # Download the new database
    TEMP_DB=$(mktemp)
    trap "rm -f $TEMP_DB" EXIT

    if ${pkgs.curl}/bin/curl -fsSL -o "$TEMP_DB" "$DB_URL"; then
      # Verify it's a valid SQLite database
      if ${pkgs.sqlite}/bin/sqlite3 "$TEMP_DB" "SELECT 1;" >/dev/null 2>&1; then
        mv "$TEMP_DB" "$DB_FILE"
        chown channelidentifiarr:channelidentifiarr "$DB_FILE"
        chmod 644 "$DB_FILE"

        # Save the new ETag
        if [[ -n "$REMOTE_ETAG" ]]; then
          echo "$REMOTE_ETAG" > "$ETAG_FILE"
          chown channelidentifiarr:channelidentifiarr "$ETAG_FILE"
        fi

        echo "Database updated successfully"
      else
        echo "Error: Downloaded file is not a valid SQLite database"
        exit 1
      fi
    else
      echo "Error: Failed to download database"
      exit 1
    fi

    # Restart the service
    echo "Starting channelidentifiarr service..."
    ${pkgs.systemd}/bin/systemctl start channelidentifiarr.service
  '';
in {
  options.rat.services.channelidentifiarr = {
    enable = options.mkEnableOption "Channelidentifiarr TV channel lineup search";

    subdomain = options.mkOption {
      type = types.str;
      default = "channelidentifiarr";
      description = "The subdomain for Channelidentifiarr.";
    };

    port = options.mkOption {
      type = types.port;
      default = 9192;
      description = "Port for Channelidentifiarr to listen on.";
    };

    workers = options.mkOption {
      type = types.int;
      default = 2;
      description = "Number of gunicorn workers.";
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for Channelidentifiarr.";
    };

    autoUpdateDatabase = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically update the database every 12 hours.";
    };

    authentik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require Authentik authentication.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.channelidentifiarr = {
        protocol = "http";
        inherit (cfg) port;
      };

      users.users.channelidentifiarr = {
        isSystemUser = true;
        group = "channelidentifiarr";
        home = stateDir;
      };
      users.groups.channelidentifiarr = {};

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0755 channelidentifiarr channelidentifiarr -"
      ];

      systemd.services.channelidentifiarr = {
        description = "Channelidentifiarr TV Channel Lineup Search";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        environment = {
          CHANNELIDENTIFIARR_BIND = "127.0.0.1:${toString cfg.port}";
          CHANNELIDENTIFIARR_WORKERS = toString cfg.workers;
        };

        serviceConfig = {
          Type = "simple";
          User = "channelidentifiarr";
          Group = "channelidentifiarr";
          WorkingDirectory = stateDir;
          StateDirectory = "channelidentifiarr";
          ExecStart = "${channelidentifiarr}/bin/channelidentifiarr";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      systemd.services.channelidentifiarr-update-db = {
        description = "Update Channelidentifiarr Database";
        after = ["network-online.target"];
        wants = ["network-online.target"];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = updateScript;
        };
      };

      systemd.timers.channelidentifiarr-update-db = modules.mkIf cfg.autoUpdateDatabase {
        description = "Timer for Channelidentifiarr Database Updates";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "12h";
          RandomizedDelaySec = "30min";
          Persistent = true;
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

      rat.services.traefik.routes.channelidentifiarr = {
        enable = true;
        inherit (cfg) subdomain authentik;
        serviceUrl = config.links.channelidentifiarr.url;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = stateDir;
          user = "channelidentifiarr";
          group = "channelidentifiarr";
          mode = "0755";
        }
      ];
    })
  ];
}

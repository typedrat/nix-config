{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) options modules mkOption types;
  cfg = config.rat.services.postgres;
  impermanenceCfg = config.rat.impermanence;

  # Databases record the glibc collation version they were created under, and
  # an index over text built under one version can be wrong under another. After
  # a glibc update changes it, this rebuilds the indexes of every database whose
  # version no longer matches and records the new one. CONCURRENTLY keeps the
  # tables writable for the services using them.
  refreshCollations = pkgs.writeShellApplication {
    name = "postgres-refresh-collations";
    runtimeInputs = [config.services.postgresql.package pkgs.util-linux];
    text = ''
      if [ "$(id -u)" -ne 0 ]; then
        echo "postgres-refresh-collations: run as root" >&2
        exit 1
      fi

      sql() {
        runuser -u postgres -- psql -X -At -v ON_ERROR_STOP=1 --port=${toString config.services.postgresql.settings.port} "$@"
      }

      mapfile -t stale < <(sql -d postgres -c \
        "SELECT datname FROM pg_database WHERE datcollversion IS DISTINCT FROM pg_database_collation_actual_version(oid) ORDER BY datname")

      if ((''${#stale[@]} == 0)); then
        echo "Every database matches the system collation version."
        exit 0
      fi

      for db in "''${stale[@]}"; do
        # template0 takes no connections and holds nothing to reindex.
        if [ "$(sql -d postgres -v db="$db" <<<"SELECT datallowconn FROM pg_database WHERE datname = :'db'")" = t ]; then
          echo "Reindexing $db..."
          sql -d "$db" -v db="$db" <<<'REINDEX DATABASE CONCURRENTLY :"db"'
        fi
        sql -d postgres -v db="$db" <<<'ALTER DATABASE :"db" REFRESH COLLATION VERSION'
      done
    '';
  };
in {
  options.rat.services.postgres = {
    enable = options.mkEnableOption "PostgreSQL";

    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          ownedDatabases = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of databases owned by the user";
          };
          passwordFile = mkOption {
            type = types.path;
            description = "Path to a file containing the user's password";
          };
        };
      });
      default = {};
      description = "Attribute set of users whose passwords should be managed";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.postgresql = {
        enable = true;
        enableJIT = true;
        package = pkgs.postgresql_16;

        # The superuser line lets root and postgres reach every database, which
        # maintenance such as postgres-refresh-collations needs; superuser_map
        # only maps those two accounts to the postgres role.
        authentication = modules.mkOverride 10 ''
          local all      postgres         peer          map=superuser_map
          local sameuser all              peer          map=superuser_map
          host  all      all 127.0.0.1/32 scram-sha-256
          host  all      all ::1/128      scram-sha-256
        '';

        identMap = ''
          # ArbitraryMapName systemUser DBUser
             superuser_map      root      postgres
             superuser_map      postgres  postgres
             # Let other names login as themselves
             superuser_map      /^(.*)$   \1
        '';

        ensureUsers = builtins.map (name: {inherit name;}) (builtins.attrNames cfg.users);
      };

      environment.systemPackages = [refreshCollations];

      links.postgres = {
        protocol = "postgresql";
        inherit (config.services.postgresql.settings) port;
      };

      systemd.services.postgres-password-update = lib.mkIf (cfg.users != {}) {
        description = "PostgreSQL User Password Update Service";
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          Group = "postgres";
        };
        wantedBy = ["multi-user.target"];
        after = ["postgresql.service"];
        requires = ["postgresql.service"];
        path = with pkgs; [
          coreutils
          config.services.postgresql.package
        ];
        environment = {
          PSQL = "psql --port=${toString config.links.postgres.port}";
        };
        script = let
          updatePasswordCommands =
            lib.mapAttrsToList (username: userConfig: ''
              # Get password from file
              password=$(cat "${userConfig.passwordFile}")

              # Update user's password
              $PSQL -c "ALTER ROLE \"${username}\" WITH ENCRYPTED PASSWORD '$password'"
              echo "Updated password for user '${username}'"

              # Ensure user owns each database from cfg.users.ownedDatabases
              ${builtins.concatStringsSep "\n" (map (database: ''
                  if $PSQL -lqt | cut -d \| -f 1 | grep -qw "${database}"; then
                    echo "Database '${database}' exists, updating owner..."
                    $PSQL -c "ALTER DATABASE \"${database}\" OWNER TO \"${username}\""
                  else
                    echo "Creating database '${database}' with owner '${username}'..."
                    $PSQL -c "CREATE DATABASE \"${database}\" OWNER \"${username}\""
                  fi
                '')
                userConfig.ownedDatabases)}
            '')
            cfg.users;
        in ''
          # Wait for PostgreSQL to be ready
          tries=0
          max_tries=30
          until $PSQL -c "SELECT 1" > /dev/null 2>&1; do
            tries=$((tries + 1))
            if [ $tries -gt $max_tries ]; then
              echo "PostgreSQL not responding after $max_tries attempts, giving up."
              exit 1
            fi
            echo "Waiting for PostgreSQL to be ready..."
            sleep 1
          done

          ${builtins.concatStringsSep "\n" updatePasswordCommands}
        '';
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = config.services.postgresql.dataDir;
          user = "postgres";
          group = "postgres";
        }
      ];
    })
  ];
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) options modules mkOption types;
  cfg = config.rat.services.postgres;
  impermanenceCfg = config.rat.impermanence;
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

        authentication = modules.mkOverride 10 ''
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

        ensureUsers = builtins.map (name: {name = name;}) (builtins.attrNames cfg.users);
      };

      links.postgres = {
        protocol = "postgresql";
        port = config.services.postgresql.settings.port;
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
                  $PSQL -c "CREATE DATABASE \"${database}\" OWNER \"${username}\"" ||
                    $PSQL -c "ALTER DATABASE \"${database}\" OWNER TO \"${username}\""
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

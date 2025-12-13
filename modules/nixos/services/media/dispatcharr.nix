{
  config,
  lib,
  pkgs,
  self',
  ...
}: let
  inherit (self'.packages) dispatcharr;

  inherit (lib) modules options types;
  cfg = config.rat.services.dispatcharr;
  impermanenceCfg = config.rat.impermanence;

  stateDir = "/var/lib/dispatcharr";

  # Common systemd service config
  commonServiceConfig = {
    User = "dispatcharr";
    Group = "dispatcharr";
    WorkingDirectory = stateDir;
    StateDirectory = "dispatcharr";
  };
in {
  options.rat.services.dispatcharr = {
    enable = options.mkEnableOption "Dispatcharr IPTV stream management";

    subdomain = options.mkOption {
      type = types.str;
      default = "dispatcharr";
      description = "The subdomain for Dispatcharr.";
    };

    logLevel = options.mkOption {
      type = types.enum ["TRACE" "DEBUG" "INFO" "WARNING" "ERROR" "CRITICAL"];
      default = "INFO";
      description = "Log level for Dispatcharr.";
    };

    celery = {
      autoscale = options.mkOption {
        type = types.submodule {
          options = {
            min = options.mkOption {
              type = types.int;
              default = 1;
              description = "Minimum number of Celery workers.";
            };
            max = options.mkOption {
              type = types.int;
              default = 6;
              description = "Maximum number of Celery workers.";
            };
          };
        };
        default = {
          min = 1;
          max = 6;
        };
        description = "Celery worker autoscaling configuration.";
      };
    };

    openFirewall = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for Dispatcharr.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.dispatcharr = {
        protocol = "http";
      };

      links.dispatcharr-redis = {
        protocol = "redis";
      };

      # User and group
      users.users.dispatcharr = {
        isSystemUser = true;
        group = "dispatcharr";
        home = stateDir;
      };
      users.groups.dispatcharr = {};

      # Redis
      services.redis.servers.dispatcharr = {
        enable = true;
        port = lib.mkForce config.links.dispatcharr-redis.port;
      };

      # PostgreSQL - use Unix socket with peer authentication
      services.postgresql = {
        enable = true;
        ensureDatabases = ["dispatcharr"];
        ensureUsers = [
          {
            name = "dispatcharr";
            ensureDBOwnership = true;
          }
        ];
      };

      # Secrets
      sops.secrets."dispatcharr/secret_key" = {
        sopsFile = ../../../../secrets/dispatcharr.yaml;
        key = "secret_key";
        restartUnits = ["dispatcharr.service" "dispatcharr-celery.service" "dispatcharr-celery-beat.service"];
        owner = "dispatcharr";
      };

      sops.templates."dispatcharr.env" = {
        content = ''
          # Django
          DJANGO_SETTINGS_MODULE=dispatcharr.settings
          DJANGO_SECRET_KEY=${config.sops.placeholder."dispatcharr/secret_key"}

          # Database Configuration - Unix socket with peer auth
          POSTGRES_DB=dispatcharr
          POSTGRES_USER=dispatcharr
          POSTGRES_HOST=/run/postgresql

          # Redis Configuration
          REDIS_HOST=localhost
          REDIS_PORT=${toString config.links.dispatcharr-redis.port}
          REDIS_DB=0
          CELERY_BROKER_URL=redis://localhost:${toString config.links.dispatcharr-redis.port}/0

          # Static/Media/Template paths
          STATICFILES_DIRS=${dispatcharr}/share/dispatcharr/frontend
          STATIC_ROOT=${stateDir}/static
          MEDIA_ROOT=${stateDir}/media
          TEMPLATE_DIRS=${dispatcharr}/share/dispatcharr/frontend

          # Application Configuration
          DISPATCHARR_LOG_LEVEL=${cfg.logLevel}
          PYTHONUNBUFFERED=1
        '';
        owner = "dispatcharr";
        group = "dispatcharr";
        mode = "0400";
        restartUnits = ["dispatcharr.service" "dispatcharr-celery.service" "dispatcharr-celery-beat.service"];
      };

      # Admin CLI wrapper script
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "dispatcharr-admin" ''
          exec ${pkgs.systemd}/bin/systemd-run \
            --pipe \
            --quiet \
            --wait \
            --collect \
            --service-type=exec \
            --property=EnvironmentFile=${config.sops.templates."dispatcharr.env".path} \
            --property=WorkingDirectory=${stateDir} \
            --property=User=dispatcharr \
            --property=Group=dispatcharr \
            -- ${dispatcharr}/bin/dispatcharr "$@"
        '')
      ];

      # Data directories
      systemd.tmpfiles.rules = [
        "d ${stateDir} 0755 dispatcharr dispatcharr -"
        "d ${stateDir}/data 0755 dispatcharr dispatcharr -"
        "d ${stateDir}/media 0755 dispatcharr dispatcharr -"
        "d ${stateDir}/static 0755 dispatcharr dispatcharr -"
      ];

      # Main Daphne ASGI server
      systemd.services.dispatcharr = {
        description = "Dispatcharr IPTV Stream Management";
        after = ["network.target" "redis-dispatcharr.service" "postgresql.service"];
        requires = ["redis-dispatcharr.service" "postgresql.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig =
          commonServiceConfig
          // {
            EnvironmentFile = config.sops.templates."dispatcharr.env".path;
            ExecStartPre = let
              preStartScript = pkgs.writeShellScript "dispatcharr-prestart" ''
                # Run Django migrations
                ${dispatcharr}/bin/dispatcharr migrate --noinput

                # Collect static files
                ${dispatcharr}/bin/dispatcharr collectstatic --noinput
              '';
            in preStartScript;
            ExecStart = "${dispatcharr}/bin/dispatcharr-daphne -b 127.0.0.1 -p ${toString config.links.dispatcharr.port} dispatcharr.asgi:application";
            Restart = "on-failure";
            RestartSec = 5;
          };
      };

      # Celery worker
      systemd.services.dispatcharr-celery = {
        description = "Dispatcharr Celery Worker";
        after = ["dispatcharr.service"];
        requires = ["dispatcharr.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig =
          commonServiceConfig
          // {
            EnvironmentFile = config.sops.templates."dispatcharr.env".path;
            ExecStart = "${dispatcharr}/bin/dispatcharr-celery -A dispatcharr worker --autoscale=${toString cfg.celery.autoscale.max},${toString cfg.celery.autoscale.min} --loglevel=${lib.toLower cfg.logLevel}";
            Restart = "on-failure";
            RestartSec = 5;
          };
      };

      # Celery beat scheduler
      systemd.services.dispatcharr-celery-beat = {
        description = "Dispatcharr Celery Beat Scheduler";
        after = ["dispatcharr.service"];
        requires = ["dispatcharr.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig =
          commonServiceConfig
          // {
            EnvironmentFile = config.sops.templates."dispatcharr.env".path;
            ExecStart = "${dispatcharr}/bin/dispatcharr-celery -A dispatcharr beat --loglevel=${lib.toLower cfg.logLevel}";
            Restart = "on-failure";
            RestartSec = 5;
          };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
        config.links.dispatcharr.port
      ];

      rat.services.traefik.routes.dispatcharr = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.dispatcharr.url;
      };
    })

    # Impermanence support
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = stateDir;
          user = "dispatcharr";
          group = "dispatcharr";
          mode = "0755";
        }
      ];
    })
  ];
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.ha-mcp;
  impermanenceCfg = config.rat.impermanence;

  inherit (config.rat.services) domainName;

  domain = "${cfg.subdomain}.${domainName}";
  stateDir = "/var/lib/ha-mcp";
in {
  options.rat.services.ha-mcp = {
    enable = options.mkEnableOption "ha-mcp, a Model Context Protocol server for Home Assistant";

    subdomain = options.mkOption {
      type = types.str;
      default = "ha-mcp";
      description = "The subdomain for ha-mcp.";
    };

    package = options.mkOption {
      type = types.package;
      default = pkgs.ha-mcp;
      defaultText = "pkgs.ha-mcp";
      description = "The ha-mcp package to run.";
    };

    enableTraefik = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable Traefik reverse proxy for ha-mcp.";
    };

    settingsUi = options.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Serve ha-mcp's web settings UI. Its routes bypass the OAuth middleware
        and are guarded only by a secret path that ha-mcp generates and logs at
        startup, so it is off by default; feature flags are set through
        `environment` instead.
      '';
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.ha-mcp = {
        protocol = "http";
      };

      systemd.services.ha-mcp = {
        description = "ha-mcp: Model Context Protocol server for Home Assistant";
        wantedBy = ["multi-user.target"];
        after = ["network.target" "home-assistant.service"];
        wants = ["home-assistant.service"];

        environment =
          {
            # Fixed server-side: the consent form used to accept a URL, which
            # made the server an SSRF probe (GHSA-fmfg-9g7c-3vq7).
            HOMEASSISTANT_URL = config.links.home-assistant.url;
            # OAuth discovery and the redirect URIs handed to clients are built
            # from this, so it has to be the public address, not the bind one.
            MCP_BASE_URL = "https://${domain}";
            MCP_HOST = "127.0.0.1";
            MCP_PORT = config.links.ha-mcp.portStr;
            MCP_SECRET_PATH = "/mcp";
            HA_MCP_CONFIG_DIR = stateDir;
            ENVIRONMENT = "production";
            LOG_LEVEL = "INFO";
          }
          // lib.optionalAttrs (!cfg.settingsUi) {
            HA_MCP_DISABLE_SETTINGS_UI = "1";
          };

        serviceConfig = {
          # ha-mcp-oauth, not ha-mcp-web: each user supplies their own Home
          # Assistant long-lived token through the consent form, so no shared
          # token has to live on the server.
          ExecStart = lib.getExe' cfg.package "ha-mcp-oauth";
          User = "ha-mcp";
          Group = "ha-mcp";
          StateDirectory = "ha-mcp";
          StateDirectoryMode = "0700";
          # ha-mcp reads $HAMCP_ENV_FILE (default ".env") relative to the
          # working directory.
          WorkingDirectory = stateDir;
          Restart = "on-failure";
          RestartSec = 5;

          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = ["@system-service" "~@privileged"];
        };
      };

      users.users.ha-mcp = {
        isSystemUser = true;
        group = "ha-mcp";
        home = stateDir;
      };
      users.groups.ha-mcp = {};
    })

    (modules.mkIf (cfg.enable && cfg.enableTraefik) {
      rat.services.traefik.routes.ha-mcp = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.ha-mcp.url;
        # Authentik forward auth would intercept the OAuth discovery and token
        # endpoints with a browser login that MCP clients cannot complete;
        # ha-mcp's own OAuth flow is the authentication here.
        authentik = false;
      };
    })

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = stateDir;
          user = "ha-mcp";
          group = "ha-mcp";
          mode = "0700";
        }
      ];
    })
  ];
}

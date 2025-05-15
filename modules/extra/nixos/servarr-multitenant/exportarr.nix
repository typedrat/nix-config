{
  config,
  pkgs,
  lib,
  ...
}: let
  supportedTypes = [
    "bazarr"
    "lidarr"
    "prowlarr"
    "radarr"
    "readarr"
    "sonarr"
    "whisparr"
  ];

  instanceOpts = {name, ...}: {
    options = {
      enable = lib.mkEnableOption "Exportarr instance ${name}";

      type = lib.mkOption {
        type = lib.types.enum supportedTypes;
        description = "Type of Servarr application to monitor";
        example = "sonarr";
      };

      url = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1";
        description = "The URL where the Servarr application is running";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the API key for the Servarr application";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "Port on which Exportarr will listen";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address on which Exportarr will listen";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to open the firewall port for Exportarr";
      };

      package = lib.mkPackageOption pkgs "exportarr" {};

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for Exportarr";
        example = {
          PROWLARR__BACKFILL = "true";
        };
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "exportarr-${name}";
        description = "User account under which Exportarr runs";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "exportarr-${name}";
        description = "Group under which Exportarr runs";
      };
    };
  };

  cfg = config.services.exportarr;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg.instances;
in {
  options = {
    services.exportarr = {
      instances = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule instanceOpts);
        default = {};
        description = "Defined Exportarr instances.";
        example = lib.literalExpression ''
          {
            sonarr-main = {
              enable = true;
              type = "sonarr";
              url = "http://localhost:8989";
              apiKeyFile = "/var/lib/secrets/sonarr-main-api-key";
              openFirewall = true;
            };
            radarr-indie = {
              enable = true;
              type = "radarr";
              url = "http://localhost:7879";
              apiKeyFile = "/var/lib/secrets/radarr-indie-api-key";
              port = 9720;
              openFirewall = true;
            };
          }
        '';
      };
    };
  };

  config = {
    systemd.services = lib.mapAttrs' (name: instance:
      lib.nameValuePair "exportarr-${name}" {
        description = "Exportarr for ${instance.type} (${name})";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        environment =
          (lib.mapAttrs (_: toString) instance.environment)
          // {
            PORT = toString instance.port;
            URL = instance.url;
            API_KEY_FILE = lib.mkIf (instance.apiKeyFile != null) "%d/api-key";
            LISTEN_ADDR = instance.listenAddress;
          };
        serviceConfig = {
          Type = "simple";
          User = instance.user;
          Group = instance.group;
          LoadCredential = lib.optionalString (instance.apiKeyFile != null) "api-key:${instance.apiKeyFile}";
          ExecStart = "${instance.package}/bin/exportarr ${instance.type}";
          Restart = "on-failure";

          # Hardening
          CapabilityBoundingSet = [""];
          DynamicUser = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallFilter = ["@system-service" "~@privileged"];
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      })
    enabledInstances;

    networking.firewall.allowedTCPPorts = lib.concatMap (
      instance:
        lib.optional instance.openFirewall instance.port
    ) (lib.attrValues enabledInstances);

    users.users =
      lib.mapAttrs' (
        name: instance:
          lib.nameValuePair instance.user (
            lib.mkIf (instance.user == "exportarr-${name}") {
              isSystemUser = true;
              inherit (instance) group;
            }
          )
      )
      enabledInstances;

    users.groups =
      lib.mapAttrs' (
        name: instance:
          lib.nameValuePair instance.group (
            lib.mkIf (instance.group == "exportarr-${name}") {}
          )
      )
      enabledInstances;
  };
}

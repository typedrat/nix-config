{
  config,
  self',
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
  torrentsCfg = config.rat.services.torrents;
in {
  config = modules.mkIf (cfg.enable && torrentsCfg.enable) {
    systemd.services.qbittorrent-exporter = {
      description = "qBittorrent metrics exporter";
      wantedBy = ["qbittorrent.service"];

      environment = {
        QBITTORRENT_BASE_URL = config.links.qbittorrent-webui.url;
        EXPORTER_PORT = builtins.toString config.links.qbittorrent-metrics.port;
        ENABLE_HIGH_CARDINALITY = "true";
      };

      serviceConfig = {
        ExecStart = lib.getExe self'.packages.qbittorrent-exporter;
        Restart = "on-failure";
        RestartSec = "5s";

        DynamicUser = true;
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
      };
    };

    links.qbittorrent-metrics = {
      protocol = "http";
    };

    services.prometheus = {
      enable = true;

      scrapeConfigs = [
        {
          job_name = "qbittorrent";
          static_configs = [
            {
              targets = [config.links.qbittorrent-metrics.tuple];
            }
          ];
        }
      ];
    };
  };
}

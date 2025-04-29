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
    systemd.services.rtorrent-exporter = {
      description = "rtorrent metrics exporter";
      after = ["rtorrent-lighttpd.service"];
      wantedBy = ["rtorrent.service"];

      serviceConfig = {
        ExecStart = builtins.concatStringsSep " " [
          "${self'.packages.rtorrent-exporter}/bin/rtorrent-exporter"
          "--config ${config.sops.secrets."rtorrent-exporter".path}"
          "--rtorrent.addr ${config.links.rtorrent.url}/RPC2"
          "--telemetry.addr ${config.links.rtorrent-metrics.tuple}"
          "--telemetry.timeout 300s" # why does this feature exist? why does it default to *10 seconds*?
          "-v 2"
        ];
        Restart = "on-failure";
        RestartSec = "5s";

        User = "rtorrent-exporter";
        Group = "rtorrent-exporter";
        ReadOnlyPaths = [config.sops.secrets."rtorrent-exporter".path];
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

    users = {
      users.rtorrent-exporter = {
        isSystemUser = true;
        home = "/var/lib/rtorrent-exporter";
        createHome = true;
        group = "rtorrent-exporter";
      };

      groups.rtorrent-exporter = {};
    };

    sops.secrets."rtorrent-exporter" = {
      sopsFile = ../../../../../../secrets/rtorrent-exporter.yaml;
      path = "/var/lib/rtorrent-exporter/.rtorrent-exporter.yaml";
      key = "";
      owner = "rtorrent-exporter";
      group = "rtorrent-exporter";
    };

    links.rtorrent-metrics = {
      protocol = "http";
    };

    services.prometheus = {
      enable = true;

      scrapeConfigs = [
        {
          job_name = "rtorrent";
          static_configs = [
            {
              targets = [config.links.rtorrent-metrics.tuple];
            }
          ];
        }
      ];
    };
  };
}

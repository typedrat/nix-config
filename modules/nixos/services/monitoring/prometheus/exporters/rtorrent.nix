{
  config,
  self',
  pkgs,
  lib,
  ...
}: let
  # This sucks, but it's necessary because `rtorrent-exporter` doesn't support binding to the `rtorrent` Unix socket
  # directly. We need to create a private network namespace, run a HTTP server in it, and then bind the exporter to
  # the HTTP server.
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
  torrentsCfg = config.rat.services.torrents;

  netnsName = "rtorrent-net";
  vethPair = {
    host = "veth-rtorrent";
    ns = "veth-ns";
  };
  hostIP = "192.168.100.1";
  nsIP = "192.168.100.2";
  lighttpdConfigFile = pkgs.writeText "lighttpd.conf" ''
    server.modules = (
      "mod_scgi"
    )

    server.bind = "127.0.0.1"
    server.port = 5000
    server.document-root = "/var/empty"

    scgi.server = (
      "/RPC2" => (
        "127.0.0.1" => (
          "socket" => "${config.services.rtorrent.rpcSocket}",
          "check-local" => "disable"
        )
      )
    )
  '';
in {
  config = modules.mkIf (cfg.enable && torrentsCfg.enable) {
    systemd.services.rtorrent-netns-setup = {
      description = "Setup network namespace for rtorrent";
      path = with pkgs; [iproute2 procps];

      before = ["rtorrent-lighttpd.service"];
      wantedBy = ["rtorrent-lighttpd.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
      };

      script = ''
        if ! ip netns list | grep -q ${netnsName}; then
          ip netns add ${netnsName}
        fi

        if ! ip link show ${vethPair.host} &>/dev/null; then
          ip link add ${vethPair.host} type veth peer name ${vethPair.ns}
        fi

        ip link set ${vethPair.ns} netns ${netnsName}

        ip addr add ${hostIP}/24 dev ${vethPair.host}
        ip link set ${vethPair.host} up

        ip netns exec ${netnsName} ip addr add ${nsIP}/24 dev ${vethPair.ns}
        ip netns exec ${netnsName} ip link set ${vethPair.ns} up
        ip netns exec ${netnsName} ip link set lo up

        ip netns exec ${netnsName} ip route add default via ${hostIP}
      '';

      preStop = ''
        ip link delete ${vethPair.host} 2>/dev/null || true
        ip netns delete ${netnsName} 2>/dev/null || true
      '';
    };

    systemd.services.rtorrent-lighttpd = {
      description = "Lighttpd SCGI service for rtorrent in private network namespace";
      after = ["rtorrent.service" "rtorrent-netns-setup.service"];
      requires = ["rtorrent-netns-setup.service"];
      wantedBy = ["rtorrent-exporter.service"];

      serviceConfig = {
        ExecStart = "${pkgs.lighttpd}/bin/lighttpd -D -f ${lighttpdConfigFile}";
        Restart = "on-failure";
        RestartSec = "5s";

        User = "rtorrent";
        Group = "media";

        NetworkNamespacePath = "/run/netns/${netnsName}";

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

    systemd.services.rtorrent-exporter = {
      description = "rtorrent metrics exporter in private network namespace";
      after = ["rtorrent-lighttpd.service" "rtorrent-netns-setup.service"];
      requires = ["rtorrent-netns-setup.service"];
      wantedBy = ["rtorrent.service"];

      serviceConfig = {
        ExecStart = builtins.concatStringsSep " " [
          "${self'.packages.rtorrent-exporter}/bin/rtorrent-exporter"
          "--config ${config.sops.secrets."rtorrent-exporter".path}"
          "--rtorrent.addr http://localhost:5000/RPC2"
          "--telemetry.addr ${nsIP}:9135"
          "--telemetry.timeout 300s" # why does this feature exist? why does it default to *10 seconds*?
        ];
        Restart = "on-failure";
        RestartSec = "5s";

        User = "rtorrent";
        Group = "media";

        NetworkNamespacePath = "/run/netns/${netnsName}";

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

    sops.secrets."rtorrent-exporter" = {
      sopsFile = ../../../../../../secrets/rtorrent-exporter.yaml;
      key = "";
      owner = "rtorrent";
      group = "media";
    };

    services.prometheus = {
      enable = true;

      scrapeConfigs = [
        {
          job_name = "rtorrent";
          static_configs = [
            {
              targets = ["${nsIP}:9135"];
              labels = {
                instance = "rtorrent";
              };
            }
          ];
        }
      ];
    };
  };
}

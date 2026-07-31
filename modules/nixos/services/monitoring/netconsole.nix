{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.netconsole;

  link = config.links.netconsole;

  logDir = "/var/log/netconsole";

  targetName = "remote";
  targetDir = "/sys/kernel/config/netconsole/${targetName}";

  setup = pkgs.writeShellApplication {
    name = "netconsole-setup";
    runtimeInputs = with pkgs; [iproute2 iputils kmod gnused gawk];
    text = ''
      target=${lib.escapeShellArg cfg.forwardTo}

      # netpoll does no address resolution of its own, so the destination has
      # to be pinned down here: a reachable address, the interface that reaches
      # it, and the neighbour's MAC. Stale AAAA records are normal on a LAN
      # where leases are recycled, hence probing each candidate rather than
      # trusting the first answer.
      pick_address() {
        local ula_only="$1" addr
        for addr in $(getent ahostsv6 "$target" | awk '{print $1}' | sort -u); do
          if [ "$ula_only" = 1 ]; then
            case "$addr" in
              fc*|fd*) ;;
              *) continue ;;
            esac
          fi
          if ping -6 -c1 -W2 "$addr" >/dev/null 2>&1; then
            echo "$addr"
            return 0
          fi
        done
        return 1
      }

      # A unique-local address survives the ISP rotating its delegated prefix,
      # so it is worth preferring even though hosts reach each other over the
      # global prefix by default.
      remote_ip=$(pick_address 1 || pick_address 0 || true)
      if [ -z "$remote_ip" ]; then
        echo "no reachable address for $target" >&2
        exit 1
      fi

      route=$(ip -6 route get "$remote_ip")
      dev=$(echo "$route" | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
      local_ip=$(echo "$route" | sed -n 's/.* src \([^ ]*\).*/\1/p' | head -1)
      remote_mac=$(ip -6 neigh get "$remote_ip" dev "$dev" | sed -n 's/.* lladdr \([^ ]*\).*/\1/p' | head -1)

      if [ -z "$dev" ] || [ -z "$local_ip" ] || [ -z "$remote_mac" ]; then
        echo "could not resolve dev/src/mac for $remote_ip" >&2
        exit 1
      fi

      modprobe netconsole

      # Attributes are read-only while a target is enabled, so tear down any
      # previous configuration before rewriting it.
      if [ -d ${targetDir} ]; then
        echo 0 > ${targetDir}/enabled || true
        rmdir ${targetDir} || true
      fi

      mkdir -p ${targetDir}
      echo "$dev"          > ${targetDir}/dev_name
      echo "$local_ip"     > ${targetDir}/local_ip
      echo "$remote_ip"    > ${targetDir}/remote_ip
      echo "$remote_mac"   > ${targetDir}/remote_mac
      echo ${link.portStr} > ${targetDir}/remote_port
      echo 1               > ${targetDir}/enabled

      echo "netconsole -> [$remote_ip]:${link.portStr} via $dev ($remote_mac)"
    '';
  };

  receiver = pkgs.writers.writePython3 "netconsole-receiver" {} ''
    import os
    import socket
    import sys

    port, outdir = int(sys.argv[1]), sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
    sock.bind(("::", port))

    # Unbuffered appends, one file per sender: whatever arrived is on disk by
    # the time the sending machine goes quiet.
    files = {}
    while True:
        data, addr = sock.recvfrom(65535)
        host = addr[0]
        handle = files.get(host)
        if handle is None:
            name = host.replace(":", "-").replace("%", "-")
            handle = files[host] = open(
                os.path.join(outdir, name + ".log"), "ab", buffering=0
            )
        if not data.endswith(b"\n"):
            data += b"\n"
        handle.write(data)
  '';
in {
  options.rat.services.netconsole = {
    forwardTo = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "iserlohn.lan";
      description = ''
        Host to stream kernel messages to via netconsole.

        printk goes out through netpoll, straight from the network driver,
        without waiting on the scheduler or any userspace process. It is the
        only channel that still reports once the machine is wedged badly enough
        that syslog never gets to run.
      '';
    };

    receiver = {
      enable = options.mkEnableOption "a receiver for netconsole kernel logs";

      allowFrom = options.mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["10.0.0.0/24"];
        description = "Source ranges permitted to send netconsole traffic to this host.";
      };
    };
  };

  config = modules.mkMerge [
    {
      links.netconsole = {
        protocol = "udp";
      };
    }

    (modules.mkIf (cfg.forwardTo != null) {
      boot.kernelModules = ["netconsole"];

      systemd.services.netconsole = {
        description = "Kernel netconsole target";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe setup;
          # The neighbour may not answer the moment the network comes up.
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        };
      };
    })

    (modules.mkIf cfg.receiver.enable {
      systemd.services.netconsole-receiver = {
        description = "Collector for remote netconsole kernel logs";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          ExecStart = "${receiver} ${link.portStr} ${logDir}";
          Restart = "always";
          RestartSec = 5;
          DynamicUser = true;
          StateDirectory = "netconsole";
          LogsDirectory = "netconsole";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
        };
      };

      rat.services.alloy = {
        enable = true;
        lokiSink = true;
      };

      environment.etc."alloy/netconsole.alloy".text = ''
        local.file_match "netconsole" {
          path_targets = [{ __path__ = "${logDir}/*.log", job = "netconsole" }]
        }

        loki.source.file "netconsole" {
          targets    = local.file_match.netconsole.targets
          forward_to = [loki.write.local.receiver]
        }
      '';

      rat.networking.scopedPorts = modules.mkIf (cfg.receiver.allowFrom != []) [
        {
          ports = [link.port];
          sources = cfg.receiver.allowFrom;
          protocol = "udp";
        }
      ];
    })
  ];
}

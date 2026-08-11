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
    runtimeInputs = with pkgs; [coreutils getent gawk gnused iproute2 iputils kmod];
    text = ''
      target=${lib.escapeShellArg cfg.forwardTo}

      # The neighbour may not answer the moment the network comes up. Nothing
      # is ordered after this unit, so waiting here delays only the logging.
      sleep 5

      # glibc synthesises ::ffff:A.B.C.D entries from a name's A records when it
      # publishes no AAAA. Nothing reaches those over v6, so they are dropped
      # here and reconsidered by the v4 pass.
      v6_addrs() {
        getent ahostsv6 "$target" 2>/dev/null | awk '{print $1}' | grep -v '^::ffff:' | sort -u || true
      }

      v4_addrs() {
        getent ahostsv4 "$target" 2>/dev/null | awk '{print $1}' | sort -u || true
      }

      # netpoll does no address resolution of its own, so the destination has
      # to be pinned down here: a reachable address, the interface that reaches
      # it, and the neighbour's MAC. Stale records are normal on a LAN where
      # leases are recycled, hence probing each candidate rather than trusting
      # the first answer.
      pick_v6() {
        local ula_only="$1" addr
        for addr in $(v6_addrs); do
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

      pick_v4() {
        local addr
        for addr in $(v4_addrs); do
          if ping -4 -c1 -W2 "$addr" >/dev/null 2>&1; then
            echo "$addr"
            return 0
          fi
        done
        return 1
      }

      # A unique-local address survives the ISP rotating its delegated prefix,
      # so it is worth preferring even though hosts reach each other over the
      # global prefix by default. v4 is tried last but is not a fallback in name
      # only: a name that resolves to no AAAA at all would otherwise leave the
      # machine with no crash logging whatsoever. The collector is not
      # necessarily answering the moment this host finishes booting, hence the
      # retries.
      remote_ip=""
      for _ in 1 2 3 4 5 6; do
        remote_ip=$(pick_v6 1 || pick_v6 0 || pick_v4 || true)
        [ -n "$remote_ip" ] && break
        sleep 10
      done

      if [ -z "$remote_ip" ]; then
        echo "no reachable address for $target" >&2
        exit 1
      fi

      case "$remote_ip" in
        *:*) family=6 ;;
        *) family=4 ;;
      esac

      route=$(ip -"$family" route get "$remote_ip" 2>/dev/null || true)
      dev=$(echo "$route" | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)

      if [ -z "$dev" ]; then
        echo "no route to $remote_ip" >&2
        exit 1
      fi

      remote_mac=$(ip -"$family" neigh get "$remote_ip" dev "$dev" 2>/dev/null | sed -n 's/.* lladdr \([^ ]*\).*/\1/p' | head -1 || true)

      # The source address deliberately does not come from `ip route get`. That
      # reports whichever address the kernel would pick, and RFC 4941 makes it
      # prefer a privacy address that rotates every few days. A netconsole
      # target holds its source for as long as it is enabled, so a rotating one
      # quietly stops delivering long before anyone looks.
      pick_local6() {
        local want_ula="$1" addr is_ula
        for addr in $(ip -6 -o addr show dev "$dev" scope global -temporary -deprecated | awk '{print $4}' | cut -d/ -f1); do
          case "$addr" in
            fc*|fd*) is_ula=1 ;;
            *) is_ula=0 ;;
          esac
          if [ "$is_ula" = "$want_ula" ]; then
            echo "$addr"
            return 0
          fi
        done
        return 1
      }

      if [ "$family" = 6 ]; then
        # Match the remote's class so the two ends stay on the same prefix.
        case "$remote_ip" in
          fc*|fd*) want_ula=1 ;;
          *) want_ula=0 ;;
        esac

        local_ip=$(pick_local6 "$want_ula" || pick_local6 "$((1 - want_ula))" || true)
      else
        # v4 has no privacy-address rotation to dodge, so the interface's own
        # address is the only candidate.
        local_ip=$(ip -4 -o addr show dev "$dev" scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
      fi

      if [ -z "$local_ip" ] || [ -z "$remote_mac" ]; then
        echo "could not resolve src/mac for $remote_ip" >&2
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

      # Extended format prefixes each message with level, sequence number and
      # timestamp. The sequence number is the point: UDP loss is likeliest
      # exactly when a machine is coming apart, and without it a gap in the log
      # is indistinguishable from a quiet moment. Not every kernel builds
      # support for it, so a refusal here is worth reporting but not fatal.
      if ! echo 1 > ${targetDir}/extended 2>/dev/null; then
        echo "kernel refused extended netconsole format, continuing without sequence numbers" >&2
      fi

      echo 1 > ${targetDir}/enabled

      echo "netconsole extended=$(cat ${targetDir}/extended)"

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
          # Deliberately not oneshot. A target implicitly orders itself after
          # everything it wants, so a oneshot here holds multi-user.target for
          # as long as the probing runs — and uwsm refuses to start a session
          # until graphical.target is active, turning an unreachable collector
          # into a minute-plus black screen at the greeter. Type=exec goes
          # active the moment the process is running and leaves the probing to
          # happen out of band; a failure still shows up as a failed unit.
          Type = "exec";
          RemainAfterExit = true;
          ExecStart = lib.getExe setup;
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
          # Deliberately not DynamicUser: that puts LogsDirectory under
          # /var/log/private, which is 0700 root, and the collector that has to
          # read these files runs as a different dynamic user and cannot
          # traverse it.
          User = "netconsole";
          Group = "netconsole";
          ReadWritePaths = [logDir];
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
        };
      };

      users.users.netconsole = {
        isSystemUser = true;
        group = "netconsole";
      };
      users.groups.netconsole = {};

      # World readable on purpose. This is the log worth reading first after a
      # machine dies, and needing a privilege dance to get at it defeats the
      # point of keeping it on disk.
      systemd.tmpfiles.rules = ["d ${logDir} 0755 netconsole netconsole -"];

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

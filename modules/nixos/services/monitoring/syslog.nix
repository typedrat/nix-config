{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.remoteSyslog;

  link = config.links.remote-syslog;
in {
  options.rat.services.remoteSyslog = {
    forwardTo = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "iserlohn.lan";
      description = ''
        Host to stream this machine's journal to as UDP syslog.

        Log shippers that poll the journal and push batches over HTTP lose
        whatever is still buffered when a machine wedges, which is exactly the
        window worth reading after a lock-up. A UDP datagram per message has no
        handshake and no batch to flush, so a line written moments before the
        freeze may already be on the wire.
      '';
    };

    receiver = {
      enable = options.mkEnableOption "a UDP syslog receiver that feeds Loki";

      allowFrom = options.mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["10.0.0.0/24"];
        description = "Source ranges permitted to send syslog to this host.";
      };
    };
  };

  config = modules.mkMerge [
    {
      links.remote-syslog = {
        protocol = "syslog";
      };
    }

    (modules.mkIf (cfg.forwardTo != null) {
      # Enabling rsyslogd flips services.journald.forwardToSyslog on by default,
      # which is what puts journal entries on /run/systemd/journal/syslog.
      services.rsyslogd = {
        enable = true;
        # journald still holds the local copy; this instance only relays.
        defaultConfig = "";
        extraConfig = ''
          *.* action(type="omfwd"
                     target="${cfg.forwardTo}"
                     port="${link.portStr}"
                     protocol="udp"
                     template="RSYSLOG_SyslogProtocol23Format"
                     queue.type="Direct"
                     action.resumeRetryCount="0")
        '';
      };
    })

    (modules.mkIf cfg.receiver.enable {
      rat.services.alloy = {
        enable = true;
        lokiSink = true;
      };

      environment.etc."alloy/syslog.alloy".text = ''
        loki.source.syslog "remote" {
          listener {
            address                = "0.0.0.0:${link.portStr}"
            protocol               = "udp"
            syslog_format          = "rfc5424"
            use_incoming_timestamp = true
            labels                 = { job = "syslog" }
          }

          relabel_rules = loki.relabel.syslog.rules
          forward_to    = [loki.write.local.receiver]
        }

        // Everything the syslog source derives from a message is __-prefixed and
        // would otherwise be dropped before it reaches Loki.
        loki.relabel "syslog" {
          forward_to = []

          rule {
            action = "labelmap"
            regex  = "__syslog_message_(hostname|severity|facility|app_name)"
          }
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

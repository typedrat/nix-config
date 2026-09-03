{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.networking;

  # ip6tables rejects IPv4 sources and iptables rejects IPv6 ones, so each
  # source range picks its own binary.
  rules =
    lib.concatMap (
      entry: let
        # `--dport` takes `low:high` for a range, so both forms reduce to one
        # argument and the rule shape stays identical.
        dports =
          map toString entry.ports
          ++ map (range: "${toString range.from}:${toString range.to}") entry.portRanges;
      in
        lib.concatMap (
          source:
            map (dport: {
              binary =
                if lib.hasInfix ":" source
                then "ip6tables"
                else "iptables";
              match = "-s ${source} -p ${entry.protocol} --dport ${dport} -j nixos-fw-accept";
            })
            dports
        )
        entry.sources
    )
    cfg.scopedPorts;

  renderRules = flag: lib.concatMapStrings (rule: "${rule.binary} ${flag} nixos-fw ${rule.match}\n") rules;
in {
  options.rat.networking.scopedPorts = options.mkOption {
    default = [];
    example = [
      {
        ports = [9100];
        sources = ["10.0.0.0/24"];
      }
    ];
    description = ''
      Ports reachable only from specific source ranges. `allowedTCPPorts` opens a
      port on every address the host answers on, which on a globally routable
      IPv6 prefix means the whole internet; these rules stay scoped to the LAN.
    '';
    type = types.listOf (types.submodule {
      options = {
        ports = options.mkOption {
          type = types.listOf types.port;
          default = [];
          description = "Ports to open.";
        };
        portRanges = options.mkOption {
          type = types.listOf (types.submodule {
            options = {
              from = options.mkOption {
                type = types.port;
                description = "First port in the range.";
              };
              to = options.mkOption {
                type = types.port;
                description = "Last port in the range, inclusive.";
              };
            };
          });
          default = [];
          description = "Contiguous port ranges to open, in addition to {option}`ports`.";
        };
        sources = options.mkOption {
          type = types.listOf types.str;
          description = "Addresses or CIDRs permitted to connect.";
        };
        protocol = options.mkOption {
          type = types.enum ["tcp" "udp"];
          default = "tcp";
          description = "Protocol to match.";
        };
      };
    });
  };

  config = modules.mkIf (rules != []) {
    assertions = [
      {
        assertion = !config.networking.nftables.enable;
        message = "rat.networking.scopedPorts appends to the iptables nixos-fw chain, which the nftables backend never consults.";
      }
    ];

    networking.firewall = {
      extraCommands = renderRules "-A";
      # Plain `stop` unhooks nixos-fw from INPUT without deleting it, so the
      # accepts have to be withdrawn by hand.
      extraStopCommands = lib.concatMapStrings (rule: "${rule.binary} -D nixos-fw ${rule.match} 2>/dev/null || true\n") rules;
    };
  };
}

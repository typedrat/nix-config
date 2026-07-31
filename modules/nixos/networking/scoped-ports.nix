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
      entry:
        lib.concatMap (
          source:
            map (port: {
              binary =
                if lib.hasInfix ":" source
                then "ip6tables"
                else "iptables";
              match = "-s ${source} -p ${entry.protocol} --dport ${toString port} -j nixos-fw-accept";
            })
            entry.ports
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
          description = "Ports to open.";
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

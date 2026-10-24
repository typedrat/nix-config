{lib, ...}: let
  inherit (lib) options types;

  proxyOptions = types.submodule {
    options = {
      exitNode = options.mkOption {
        type = types.str;
        description = ''
          Exit node to route through, as a tailnet IP or MagicDNS name. A
          name is matched against the peer list, which is empty until the
          node finishes connecting and errors if two peers share the name;
          an IP has neither problem.
        '';
        example = "100.101.102.103";
      };

      socksPort = options.mkOption {
        type = types.port;
        description = "Loopback port for the SOCKS5 proxy. Must be unique across proxies.";
        example = 5040;
      };

      httpPort = options.mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Loopback port for an HTTP proxy, for tools that only read `http_proxy`.";
        example = 5041;
      };

      browser.enable = options.mkEnableOption ''
        a Google Chrome launcher with its own profile that sends all traffic,
        DNS and WebRTC included, through this proxy
      '';
    };
  };
in {
  options.rat.users = options.mkOption {
    type = types.attrsOf (types.submodule {
      options.cli.networking.tailsocks = options.mkOption {
        type = types.attrsOf proxyOptions;
        default = {};
        description = ''
          Local proxies that each join the tailnet as their own node and exit
          through a chosen exit node, so single applications can use it
          without routing the whole machine.
        '';
      };
    });
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.networking.bridge;
in {
  options.rat.networking.bridge = {
    enable = options.mkEnableOption "a host bridge onto the LAN, for emulators and VMs that attach TAP devices to it";

    name = options.mkOption {
      type = types.str;
      default = "br0";
      description = "Name of the bridge interface.";
    };

    interface = options.mkOption {
      type = types.str;
      example = "enp5s0";
      description = ''
        Wired interface to make a port of the bridge. The host's own addresses
        move onto the bridge with it. Wi-Fi can't be bridged this way: an
        access point drops frames from MACs that haven't associated with it.
      '';
    };

    macAddress = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "00:11:22:33:44:55";
      description = ''
        MAC address for the bridge. Set it to the port's own address to keep
        the DHCP lease and EUI-64 addresses the host had before bridging;
        otherwise the bridge gets a generated MAC and the router sees a new
        machine.
      '';
    };
  };

  config = modules.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rat.networking.networkManager.enable;
        message = "rat.networking.bridge is built from NetworkManager profiles; enable rat.networking.networkManager.";
      }
    ];

    networking.networkmanager.ensureProfiles.profiles = {
      ${cfg.name} = {
        connection = {
          id = cfg.name;
          type = "bridge";
          interface-name = cfg.name;
        };
        bridge =
          {
            # STP holds a new port in the listening state for ~30s, which a
            # guest's DHCP client times out on. One bridge with one uplink
            # can't form a loop anyway.
            stp = false;
          }
          // lib.optionalAttrs (cfg.macAddress != null) {
            mac-address = cfg.macAddress;
          };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

      "${cfg.name}-${cfg.interface}" = {
        connection = {
          id = "${cfg.name}-${cfg.interface}";
          type = "ethernet";
          interface-name = cfg.interface;
          master = cfg.name;
          slave-type = "bridge";
          # Wins over the automatic "Wired connection" profile, which would
          # otherwise keep the interface out of the bridge.
          autoconnect-priority = 10;
        };
      };
    };
  };
}

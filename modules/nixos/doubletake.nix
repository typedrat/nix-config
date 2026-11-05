{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;

  doubletakeUsers =
    lib.filterAttrs
    (_: userCfg:
      userCfg.enable
      && (userCfg.gui.enable or false)
      && (userCfg.gui.media.enable or false)
      && (userCfg.gui.media.doubletake.enable or false))
    config.rat.users;
in {
  config = modules.mkIf (doubletakeUsers != {}) {
    # Receivers probe the timing port during SETUP and send audio retransmission
    # requests back to the control port, both inbound and unsolicited as far as
    # connection tracking is concerned.
    rat.networking.scopedPorts = [
      {
        protocol = "udp";
        sources = config.rat.networking.lanRanges;
        portRanges = lib.mapAttrsToList (_: userCfg: userCfg.gui.media.doubletake.portRange) doubletakeUsers;
      }
    ];
  };
}

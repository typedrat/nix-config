{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules;

  wiresharkUsers =
    lib.filterAttrs
    (_: userCfg:
      userCfg.enable
      && (userCfg.gui.enable or false)
      && (userCfg.gui.development.enable or false)
      && (userCfg.gui.development.wireshark.enable or false))
    config.rat.users;
in {
  config = modules.mkIf (wiresharkUsers != {}) {
    # Installs Wireshark and a dumpcap wrapper with capture capabilities that
    # only the wireshark group can run.
    programs.wireshark = {
      enable = true;
      package = pkgs.wireshark;
      dumpcap.enable = true;
    };

    users.users = lib.mapAttrs (_: _: {extraGroups = ["wireshark"];}) wiresharkUsers;
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.rat.hardware.scanning;

  scannerUsers =
    lib.filterAttrs
    (_: userCfg: userCfg.enable && (userCfg.gui.enable or false))
    config.rat.users;
in {
  options.rat.hardware.scanning.enable =
    mkEnableOption "scanning"
    // {
      default = config.rat.hardware.printing.enable;
    };

  config = mkIf cfg.enable {
    hardware.sane = {
      enable = true;

      # The DCP-L2550DW exposes no IPP-USB interface, only Brother's
      # vendor-specific scan interface (ff/ff/ff), so sane-airscan has nothing
      # to talk to over USB and a proprietary backend is the only option.
      # brscan5 ships this model commented out of its table; brscan4 claims it.
      brscan4.enable = true;
    };

    # Brother's udev rule only tags the device with libsane_matched, leaving the
    # ACL that sane's own rule then grants to "scanner" as the sole thing that
    # opens it; "lp" covers the printer half of the same device.
    users.users = lib.mapAttrs (_: _: {extraGroups = ["scanner" "lp"];}) scannerUsers;
  };
}

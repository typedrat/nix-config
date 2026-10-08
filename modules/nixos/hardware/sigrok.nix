{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.sigrok.enable = mkEnableOption "sigrok logic analyzer and instrument support";

  config = mkIf config.rat.hardware.sigrok.enable {
    # libsigrok ships the udev rules (uaccess for the local seat) and the
    # fx2lafw firmware that cheap Cypress FX2 analyzers need uploaded.
    services.udev.packages = [pkgs.libsigrok];

    # The plugdev rules file names the group; without it udev logs warnings.
    users.groups.plugdev = {};

    environment.systemPackages = [
      pkgs.sigrok-cli
      pkgs.pulseview
    ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.esp32Dev.enable = mkEnableOption "ESP32 development device access";

  config = mkIf config.rat.hardware.esp32Dev.enable {
    services.udev = {
      packages = [pkgs.probe-rs-tools];

      # Espressif's built-in USB-Serial-JTAG. uaccess grants the local seat's
      # user access, so no dialout membership is needed.
      extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="303a", MODE="0660", GROUP="dialout", TAG+="uaccess"
        SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0660", GROUP="dialout", TAG+="uaccess"
      '';
    };

    users.groups.plugdev = {};
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.usbmuxd.enable = mkEnableOption "usbmuxd for iOS device connectivity";

  config = mkIf config.rat.hardware.usbmuxd.enable {
    services.usbmuxd.enable = true;
  };
}

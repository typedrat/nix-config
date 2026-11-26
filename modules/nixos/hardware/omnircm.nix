{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.omnircm.enable = mkEnableOption "OmniRCM, the Nintendo Switch RCM payload injector";

  config = mkIf config.rat.hardware.omnircm.enable {
    environment.systemPackages = [pkgs.omnircm];

    # The Switch in RCM shows up as the Tegra's APX recovery device. uaccess
    # only takes effect when set before 73-seat-late.rules, so this can't go
    # in extraRules (99-local.rules).
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-nintendo-switch-rcm.rules" ''
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0955", ATTRS{idProduct}=="7321", TAG+="uaccess"
      '')
    ];
  };
}

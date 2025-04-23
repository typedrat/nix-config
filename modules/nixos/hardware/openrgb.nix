{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.openrgb.enable = mkEnableOption "OpenRGB";

  config = mkIf config.rat.hardware.openrgb.enable {
    services.hardware.openrgb = {
      enable = true;
      package = pkgs.openrgb-with-all-plugins;
    };

    boot.kernelModules = ["i2c-dev"];
  };
}

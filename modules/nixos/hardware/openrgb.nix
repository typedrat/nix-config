{
  config,
  inputs',
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  openrgb = inputs'.nanopkgs.packages.openrgb.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        # Add support for MSI MPG X870I EDGE TI EVO WIFI (MS-7E50)
        # https://gitlab.com/CalcProgrammer1/OpenRGB/-/merge_requests/3154
        (pkgs.fetchpatch {
          url = "https://gitlab.com/CalcProgrammer1/OpenRGB/-/merge_requests/3154.diff";
          hash = "sha256-MZhM0h9//O1UGJOfAUYO+Z2U+fwlMVgiMtVBLLcgsEs=";
        })
      ];
  });
in {
  options.rat.hardware.openrgb.enable = mkEnableOption "OpenRGB";

  config = mkIf config.rat.hardware.openrgb.enable {
    services.hardware.openrgb = {
      enable = true;
      package = openrgb;
    };

    programs.coolercontrol.enable = true;

    boot.kernelModules = ["i2c-dev"];
  };
}

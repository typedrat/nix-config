{
  config,
  inputs',
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.rat.hardware.openrgb;
  impermanenceCfg = config.rat.impermanence;

  inherit (inputs'.nanopkgs.packages) openrgb;
in {
  options.rat.hardware.openrgb.enable = mkEnableOption "OpenRGB";

  config = mkMerge [
    (mkIf cfg.enable {
      services.hardware.openrgb = {
        enable = true;
        package = openrgb;
      };

      programs.coolercontrol.enable = true;

      boot.kernelModules = ["i2c-dev"];
    })
    (mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          "/etc/coolercontrol"
          "/var/lib/OpenRGB"
        ];
      };
    })
  ];
}

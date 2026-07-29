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

  # `legacyPackages`, not `packages`: the latter is a `meta`-filtered view of the
  # same scope, and filtering forces every nanopkgs package, so one that fails to
  # evaluate takes the whole set down with it.
  inherit (inputs'.nanopkgs.legacyPackages) openrgb;
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

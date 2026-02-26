{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.rat.hardware.openrgb.enable or false) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/OpenRGB"];
    };
  };
}

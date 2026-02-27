{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.programs.coolercontrol.enable or false) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [
        ".config/org.coolercontrol.CoolerControl"
        ".local/share/org.coolercontrol.CoolerControl"
      ];
    };
  };
}

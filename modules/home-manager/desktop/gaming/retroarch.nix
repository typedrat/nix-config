{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  gamingCfg = guiCfg.gaming or {};
  retroarchCfg = gamingCfg.retroarch or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf ((guiCfg.enable or false) && retroarchCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/retroarch"];
    };
    home.packages = [
      (pkgs.retroarch.withCores retroarchCfg.cores)
      pkgs.skyscraper
    ];
  };
}

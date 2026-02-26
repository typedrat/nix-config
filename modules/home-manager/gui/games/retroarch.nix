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
  gamesCfg = guiCfg.games or {};
  retroarchCfg = gamesCfg.retroarch or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf ((guiCfg.enable or false) && retroarchCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [".config/retroarch"];
    };
    home.packages = [
      (pkgs.retroarch.withCores retroarchCfg.cores)
      pkgs.skyscraper
    ];
  };
}

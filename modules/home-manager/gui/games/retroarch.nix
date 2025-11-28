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
in {
  config = modules.mkIf ((guiCfg.enable or false) && retroarchCfg.enable) {
    home.packages = [
      (pkgs.retroarch.withCores retroarchCfg.cores)
      pkgs.skyscraper
    ];
  };
}

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
  lichiiCfg = gamingCfg.lichii or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && lichiiCfg.enable) {
    home.packages = [pkgs.lichii];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Settings (qt-config.ini, etc.)
        ".config/lichii"
        # Keys, NAND, SD card, save data, installed games, and shader caches
        ".local/share/lichii"
      ];
    };
  };
}

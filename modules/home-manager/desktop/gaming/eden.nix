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
  edenCfg = gamingCfg.eden or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && edenCfg.enable) {
    home.packages = [pkgs.eden];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Settings (qt-config.ini, etc.)
        ".config/eden"
        # Keys, NAND, SD card, save data, installed games, and shader caches
        ".local/share/eden"
      ];
    };
  };
}

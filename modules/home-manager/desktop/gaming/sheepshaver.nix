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
  sheepshaverCfg = gamingCfg.sheepshaver or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && sheepshaverCfg.enable) {
    home.packages = [pkgs.sheepshaver-bin];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Emulator settings and the emulated Mac's NVRAM
        ".config/SheepShaver"
      ];
    };
  };
}

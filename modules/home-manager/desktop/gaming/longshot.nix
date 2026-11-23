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
  longshotCfg = gamingCfg.longshot or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && longshotCfg.enable) {
    home.packages = [pkgs.longshot-launcher];

    # The built game goes to ~/Games/Longshot, which the gaming module persists.
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Saves, NFC tags, and the launcher's builders, toolchains and build files
        ".local/share/longshot"
      ];
    };
  };
}

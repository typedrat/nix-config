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
  dosboxXCfg = gamingCfg.dosboxX or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && dosboxXCfg.enable) {
    home.packages = [pkgs.dosbox-x];

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        # Per-version dosbox-x-<version>.conf and mapper files
        ".config/dosbox-x"
        # User-supplied resources (shaders, fonts, languages)
        ".local/share/dosbox-x"
      ];
    };
  };
}

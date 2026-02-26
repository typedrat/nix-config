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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf ((guiCfg.enable or false) && (guiCfg.graphics.enable or false)) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [".config/inkscape"];
    };
    home.packages = with pkgs; [
      gimp3
      inkscape
      imgbrd-grabber
    ];
  };
}

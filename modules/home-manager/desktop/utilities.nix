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
  config = modules.mkIf (guiCfg.enable && guiCfg.utilities.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".config/transmission"
        ".config/tenacity"
        ".local/share/qalculate"
        ".config/qalculate"
      ];
    };
    home.packages = with pkgs; [
      qalculate-qt
      transmission_4-qt6
      waypipe
      wev
      wl-clipboard
      xcursor-viewer
    ];
  };
}

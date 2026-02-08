{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  wallpaperCfg = hyprlandCfg.wallpaper or {};
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (wallpaperCfg.enable or false)
      && (wallpaperCfg.variant or "hyprpaper") == "hyprpaper"
    ) {
      services.hyprpaper = {
        enable = true;
        settings = {
          splash = false;
        };
      };
    };
}

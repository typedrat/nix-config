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
  wallpaperImage = guiCfg.wallpaper.image or null;
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
      && wallpaperCfg.enable
      && (wallpaperCfg.variant or "hyprpaper") == "hyprpaper"
    ) {
      services.hyprpaper = {
        enable = true;
        settings =
          {
            splash = false;
          }
          // lib.optionalAttrs (wallpaperImage != null) {
            wallpaper = [
              {
                monitor = "*";
                path = wallpaperImage;
                fit_mode = "cover";
              }
            ];
          };
      };
    };
}

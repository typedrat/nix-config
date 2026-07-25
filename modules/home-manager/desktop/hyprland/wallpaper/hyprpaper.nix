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
            preload = [wallpaperImage];
            # Empty monitor field applies the wallpaper to every output.
            wallpaper = [",${wallpaperImage}"];
          };
      };
    };
}

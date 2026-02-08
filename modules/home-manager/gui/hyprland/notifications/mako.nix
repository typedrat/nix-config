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
  notificationsCfg = hyprlandCfg.notifications or {};
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (notificationsCfg.enable or true)
      && (notificationsCfg.variant or "mako") == "mako"
    ) {
      services.mako = {
        enable = true;
        settings = {
          defaultTimeout = "5000";
          font = "SF Pro Display 14";
          width = "600";
        };
      };
    };
}

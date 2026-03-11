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
  logoutCfg = hyprlandCfg.logout or {};
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (logoutCfg.enable or false)
      && (logoutCfg.variant or "wlogout") == "wlogout"
    ) {
      programs.wlogout = {
        enable = true;
      };
    };
}

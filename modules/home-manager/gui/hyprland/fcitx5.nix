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
  hyprlandCfg = guiCfg.hyprland or {};
in {
  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-mozc-ut
        ];
      };
    };

    wayland.windowManager.hyprland.extraConfig = ''
      windowrule {
        name = fcitx-pseudo
        match:class = .*fcitx.*
        pseudo = on
      }
    '';
  };
}

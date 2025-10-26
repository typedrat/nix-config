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
    programs.rofi = {
      enable = true;
      plugins = with pkgs; [
        rofi-games
      ];

      catppuccin.enable = true;

      terminal = "${pkgs.wezterm}/bin/wezterm";
      extraConfig = {
        modi = "drun";
        show-icons = true;
        drun-display-format = "{name}";
        disable-history = false;
        sidebar-mode = false;
      };
    };

    wayland.windowManager.hyprland.settings = {
      "$ROFI_CMD" = "rofi -show drun";

      bind = [
        "$main_mod,d,exec,$ROFI_CMD"
      ];
    };
  };
}

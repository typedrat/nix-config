{
  config,
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  hyprbarsCfg = hyprlandCfg.hyprbars or {};

  palette = (lib.importJSON "${config.catppuccin.sources.palette}/palette.json").${config.catppuccin.flavor}.colors;
  mkRgb = color: "rgb(${lib.removePrefix "#" palette.${color}.hex})";
  mkRgba = color: alpha: "rgba(${lib.removePrefix "#" palette.${color}.hex}${alpha})";
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
      && hyprbarsCfg.enable
    ) {
      wayland.windowManager.hyprland = {
        plugins = [
          inputs.hyprland-plugins.packages.${pkgs.stdenv.system}.hyprbars
        ];

        settings = {
          plugin = {
            hyprbars = {
              bar_height = 36;
              bar_precedence_over_border = true;
              bar_text_font = "SF Pro Display";
              bar_text_size = 16;
              bar_color = mkRgba "base" "a0";
              bar_blur = true;
              "col.text" = mkRgb "text";

              bar_buttons_alignment = "right";
              hyprbars-button = [
                "${mkRgb "red"}, 20, 󰖭, hyprctl dispatch killactive, ${mkRgb "base"}"
                "${mkRgb "yellow"}, 20, 󰖰, hyprctl dispatch movetoworkspacesilent special:minimized, ${mkRgb "base"}"
                "${mkRgb "green"}, 20, 󰘖, hyprctl dispatch fullscreen 1, ${mkRgb "base"}"
              ];
            };
          };
        };
      };
    };
}

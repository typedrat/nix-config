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
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (hyprbarsCfg.enable or false)
    ) {
      wayland.windowManager.hyprland = {
        plugins = [
          inputs.hyprland-plugins.packages.${pkgs.stdenv.system}.hyprbars
        ];

        settings = {
          plugin = {
            hyprbars = {
              bar_height = 30;
              bar_precedence_over_border = true;
              bar_text_font = "SF Pro Display";
              bar_text_size = 10;
              bar_color = "rgba($baseAlphaa0)";
              bar_blur = true;
              "col.text" = "$text";

              bar_buttons_alignment = "right";
              hyprbars-button = [
                "$red, 20, 󰖭, hyprctl dispatch killactive, $base"
                "$yellow, 20, 󰖰, hyprctl dispatch movetoworkspacesilent special:minimized, $base"
                "$green, 20, 󰘖, hyprctl dispatch fullscreen 1, $base"
              ];
            };
          };
        };
      };
    };
}

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

  # This hyprbars build adds buttons through a plugin Lua function rather than
  # the old `hyprbars-button` keyword. The plugin only exists on Hyprland's
  # second config pass (the first records it via hl.plugin.load; the plugin
  # system then loads it and reloads), so the calls are guarded.
  buttons = [
    {
      bg = mkRgb "red";
      icon = "󰖭";
      action = "hyprctl dispatch killactive";
    }
    {
      bg = mkRgb "yellow";
      icon = "󰖰";
      action = "hyprctl dispatch movetoworkspacesilent special:minimized";
    }
    {
      bg = mkRgb "green";
      icon = "󰘖";
      action = "hyprctl dispatch fullscreen 1";
    }
  ];
  renderButton = b: ''hl.plugin.hyprbars.add_button({ bg_color = ${builtins.toJSON b.bg}, fg_color = ${builtins.toJSON (mkRgb "base")}, size = 20, icon = ${builtins.toJSON b.icon}, action = ${builtins.toJSON b.action} })'';
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
          config.plugin = {
            hyprbars = {
              bar_height = 36;
              bar_precedence_over_border = true;
              bar_text_font = "SF Pro Display";
              bar_text_size = 16;
              bar_color = mkRgba "base" "a0";
              bar_blur = true;
              "col.text" = mkRgb "text";

              bar_buttons_alignment = "right";
            };
          };

          # Ghidra spawns transient child windows (titled win16, win17, ...)
          # that should not get a titlebar of their own.
          window_rule = [
            {
              name = "ghidra-no-bar";
              match = {
                initial_class = "^(ghidra-Ghidra)$";
                initial_title = "^(win\\d+)$";
              };
              "hyprbars:no_bar" = true;
            }
          ];
        };

        extraConfig = ''
          if hl.plugin.hyprbars then
          ${lib.concatMapStringsSep "\n" renderButton buttons}
          end
        '';
      };
    };
}

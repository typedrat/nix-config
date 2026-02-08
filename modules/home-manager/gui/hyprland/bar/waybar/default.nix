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
  barCfg = hyprlandCfg.bar or {};
  hostHyprlandCfg = osConfig.rat.gui.hyprland or {};
  primaryMonitor = hostHyprlandCfg.primaryMonitor or null;

  # Check if features are enabled for conditional button rendering
  pyprlandEnabled = hyprlandCfg.pyprland.enable or false;
  logoutCfg = hyprlandCfg.logout or {};
  logoutEnabled = (logoutCfg.enable or false) && (logoutCfg.variant or "wlogout") == "wlogout";
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (barCfg.enable or true)
      && (barCfg.variant or "waybar") == "waybar"
    ) {
      wayland.windowManager.hyprland.settings = {
        exec-once = [
          "waybar"
        ];
      };

      programs.waybar = {
        enable = true;

        settings = [
          ({
              reload_style_on_change = true;
              layer = "top";
              modules-left =
                ["hyprland/workspaces"]
                ++ lib.optional pyprlandEnabled "custom/spotify"
                ++ ["clock"];
              modules-right =
                ["tray" "wireplumber"]
                ++ lib.optional logoutEnabled "custom/wlogout";

              "hyprland/workspaces" = {
                "persistent-workspaces" = {
                  "*" = 6;
                };
              };

              clock = {
                format = "<span foreground='#babbf1'></span> {:%I:%M %p}";
                tooltip-format = "<span foreground='#babbf1'>󰃶</span> {:%A, %B %d, %Y}";
              };

              tray = {
                spacing = 9;
              };

              wireplumber =
                {
                  format = "{icon}";
                  tooltip-format = "{node_name} — {volume}%";
                  format-muted = " ";
                  format-icons = [" " " " " "];
                }
                // lib.optionalAttrs pyprlandEnabled {
                  on-click = "pypr toggle pwvucontrol";
                };
            }
            // lib.optionalAttrs logoutEnabled {
              "custom/wlogout" = {
                format = "󰩈";
                tooltip = false;
                on-click = "${lib.getExe pkgs.wlogout}";
              };
            }
            // lib.optionalAttrs pyprlandEnabled {
              "custom/spotify" = {
                format = "󰓇";
                tooltip = false;
                on-click = "pypr toggle spotify";
              };
            }
            // lib.optionalAttrs (primaryMonitor != null) {output = primaryMonitor;})
        ];

        style = ./waybar.css;
      };
    };
}

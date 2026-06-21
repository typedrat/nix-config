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
  pyprlandEnabled = hyprlandCfg.pyprland.enable;
  logoutCfg = hyprlandCfg.logout or {};
  logoutEnabled = logoutCfg.enable && (logoutCfg.variant or "wlogout") == "wlogout";
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
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
                # Only show the numbered workspaces (1-6) that are bound to the
                # primary monitor. The previous `"*" = 6` wildcard told waybar to
                # create 6 persistent slots on *every* output, which collided with
                # the per-monitor workspace bindings (named `tv` workspace on the
                # secondary, headless `sunshine` output, etc.) and caused the bar
                # to render stray workspaces (7, 8, ...) with gaps. Pinning the
                # persistent set to this bar's own output (the primary monitor)
                # keeps the numbering as 1-6.
                "persistent-workspaces" = lib.optionalAttrs (primaryMonitor != null) {
                  ${primaryMonitor} = [1 2 3 4 5 6];
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
                  format-muted = "󰝟 ";
                  format-icons = ["󰕿 " "󰖀 " "󰕾 "];
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

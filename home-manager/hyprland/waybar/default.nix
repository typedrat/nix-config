{
  pkgs,
  lib,
  ...
}: {
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "waybar"
    ];
  };

  programs.waybar = {
    enable = true;

    settings = [
      {
        reload_style_on_change = true;
        layer = "top";
        output = "DP-2";
        modules-left = ["hyprland/workspaces" "custom/spotify" "clock"];
        modules-right = ["tray" "wireplumber" "custom/wlogout"];

        "hyprland/workspaces" = {
          "persistent-workspaces" = {
            "*" = 6;
          };
        };

        "custom/spotify" = {
          format = "󰓇";
          tooltip = false;
          on-click = "pypr toggle spotify";
        };

        clock = {
          format = "<span foreground='#babbf1'></span> {:%I:%M %p}";
          tooltip-format = "<span foreground='#babbf1'>󰃶</span> {:%A, %B %d, %Y}";
        };

        tray = {
          spacing = 9;
        };

        wireplumber = {
          format = "{icon}";
          tooltip-format = "{node_name} — {volume}%";
          format-muted = " ";
          format-icons = [" " " " " "];
          on-click = "pypr toggle pwvucontrol";
        };

        "custom/wlogout" = {
          format = "󰩈";
          tooltip = false;
          on-click = "${lib.getExe pkgs.wlogout}";
        };
      }
    ];

    style = ./waybar.css;
  };
}

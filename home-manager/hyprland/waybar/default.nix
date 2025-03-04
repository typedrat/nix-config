{
  programs.waybar = {
    enable = true;

    settings = [
      {
        reload_style_on_change = true;
        layer = "top";
        output = "DP-2";
        modules-left = ["hyprland/workspaces" "clock"];
        modules-right = ["tray" "wireplumber" "custom/wlogout"];

        "hyprland/workspaces" = {
          "persistent-workspaces" = {
            "*" = 6;
          };
        };

        clock = {
          format = "{:%I:%M %p}  ";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
          };
        };

        tray = {
          spacing = 9;
        };

        wireplumber = {
          format = "{icon}";
          tooltip-format = "{node_name} — {volume}%";
          format-muted = "";
          format-icons = ["" "" ""];
        };

        "custom/wlogout" = {
          format = "󰩈";
          on-click = "wlogout";
        };
      }
    ];

    style = ./waybar.css;
  };
}

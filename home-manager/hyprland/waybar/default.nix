{
  pkgs,
  lib,
  ...
}: {
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
          format = "󰃶 {:%A, %B %d, %Y  %I:%M %p}";
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
          format-muted = " ";
          format-icons = [" " " " " "];
          on-click = "${lib.getExe pkgs.pwvucontrol}";
        };

        "custom/wlogout" = {
          format = "󰩈";
          on-click = "${lib.getExe pkgs.wlogout}";
        };
      }
    ];

    style = ./waybar.css;
  };

  home.packages = [
    pkgs.pwvucontrol
  ];
}

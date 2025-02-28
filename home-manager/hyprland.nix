{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.walker.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    hyprpolkitagent
    mpvpaper
    waypaper
    nwg-look
    libsForQt5.qt5ct
    kdePackages.qt6ct
    nomacs-qt6
    kdePackages.okular
    kdePackages.dolphin
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;

    package = null;
    portalPackage = null;

    settings = {
      monitor = [
        "DP-2,3840x2160@60.0,0x1080,1.0"
        "HDMI-A-1,3840x2160@60.0,960x0,2.0"
      ];

      bind = [
        "SUPER,space,exec,walker"
      ];

      bindm = [
        "Alt,mouse:272,movewindow"
      ];

      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waypaper --restore"
        "waybar"
        "walker --gapplication-service"
        "nwg-drawer -r -term wezterm -wm hyprland"
        "firefox"
        "wezterm"
      ];
    };
  };

  home.pointerCursor.hyprcursor.enable = true;

  stylix.targets = {
    hyprland.hyprpaper.enable = false;
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  services.mako = {
    enable = true;
    defaultTimeout = 30;
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "podif hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  programs.hyprlock.enable = true;

  programs.waybar = {
    enable = true;

    settings = [
      {
        "layer" = "top";
        "modules-left" = ["hyprland/workspaces" "hyprland/mode"];
        "modules-center" = ["hyprland/window"];
        "modules-right" = ["tray" "wireplumber" "clock"];

        "hyprland/window" = {
          "max-length" = 50;
        };

        "wireplumber" = {
          "format" = "{volume}% {icon}";
          "format-muted" = "";
          "format-icons" = ["" "" ""];
        };

        "clock" = {
          "format" = "{:%I:%M %p}  ";
          "tooltip-format" = "<tt><small>{calendar}</small></tt>";
        };
      }
    ];
  };

  programs.walker = {
    enable = true;
  };
}

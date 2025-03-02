{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.catppuccin.homeManagerModules.catppuccin
    inputs.spicetify-nix.homeManagerModules.default
    inputs.walker.homeManagerModules.default

    ./smart-gaps.nix
    ./xwaylandvideobridge.nix
  ];

  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

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

    plugins = [
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
    ];

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

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  services.mako = {
    enable = true;
    defaultTimeout = 30;
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
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
        reload_style_on_change = true;
        layer = "top";
        output = "DP-2";
        modules-left = ["hyprland/workspaces" "clock"];
        modules-center = ["hyprland/window"];
        modules-right = ["tray" "wireplumber"];

        "hyprland/workspaces" = {
          "persistent-workspaces" = {
            "*" = 5;
          };
        };

        "hyprland/window" = {
          "max-length" = 50;
        };

        wireplumber = {
          format = "{icon}";
          tooltip-format = "{node_name} — {volume}%";
          format-muted = "";
          format-icons = ["" "" ""];
        };

        clock = {
          format = "{:%I:%M %p}  ";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
          };
        };
      }
    ];

    style = ./waybar.css;
  };

  programs.walker = {
    enable = true;
  };

  programs.wlogout = {
    enable = true;
  };
}

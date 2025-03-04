{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./firefox
    ./smart-gaps.nix
    ./waybar
    ./xwaylandvideobridge.nix
  ];

  nix.settings = {
    extra-substituters = ["https://hyprland.cachix.org"];
    extra-trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
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
    kdePackages.ark
    xmage
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

      workspace = [
        "1, monitor:DP-2, persistent=true"
        "2, monitor:DP-2, persistent=true"
        "3, monitor:DP-2, persistent=true"
        "4, monitor:DP-2, persistent=true"
        "5, monitor:DP-2, persistent=true"
        "6, monitor:DP-2, persistent=true"
        "name:tv, monitor:HDMI-A-1, persistent=true"
      ];

      windowrulev2 = [
        "float, class:xdg-desktop-portal-gtk"
      ];

      bind = [
        "SUPER,space,exec,walker"
        "CTRL,left,workspace,r-1"
        "CTRL,right,workspace,r+1"
      ];

      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waypaper --restore"
        "waybar"
        "walker --gapplication-service"
        "jellyfin-mpv-shim"
        "firefox"
        "wezterm"
      ];
    };
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  services.mako = {
    enable = true;
    defaultTimeout = 5000;
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

  programs.hyprlock = {
    enable = true;

    settings = {
      "$font" = "SF Pro Display";

      general = {
        disable_loading_bar = true;
        hide_cursor = true;
      };

      label = [
      ];
    };
  };

  programs.walker = {
    enable = true;
  };

  programs.wlogout = {
    enable = true;
  };
}

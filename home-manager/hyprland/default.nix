{pkgs, ...}: {
  imports = [
    ./firefox
    ./hyprlock
    ./kde
    ./waybar
    ./blur.nix
    ./hyprbars.nix
    ./pyprland.nix
    ./rofi.nix
    ./smart-gaps.nix
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
    hyprpicker
    hyprshot
    playerctl
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

    settings = {
      "$main_mod" = "SUPER";

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
        "float, class:[Ss]team, title:negative:Steam"
        "float, class:.*blueman.*"
        "monitor HDMI-A-1, class:mpv"
      ];

      bind = [
        "$main_mod&SHIFT,left,workspace,r-1"
        "$main_mod&SHIFT,right,workspace,r+1"
        "$main_mod,s,exec,hyprshot -m window"
        "$main_mod&SHIFT,s,exec,hyprshot -m region"
        "$main_mod,l,exec,loginctl lock-session"
        "$main_mod,f,togglefloating"
      ];

      bindl = [
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      bindm = [
        "ALT, mouse:272, movewindow"
      ];

      exec-once = [
        "systemctl --user start hyprpolkitagent"
        "waypaper --restore"
        "STEAM_FRAME_FORCE_CLOSE=1 steam -silent"
        "discord --start-minimized"
        "jellyfin-mpv-shim"
        "pyvizio power on"
      ];

      general = {
        resize_on_border = true;
        extend_border_grab_area = 30;
        hover_icon_on_border = true;
        "col.inactive_border" = "$crust";
        "col.active_border" = "$overlay2";

        snap = {
          enabled = true;
          border_overlap = true;
        };
      };

      decoration = {
        rounding = 10;
      };
    };
  };

  home.sessionVariables.HYPRSHOT_DIR = "$HOME/Pictures/Screenshots";
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

  programs.wlogout = {
    enable = true;
  };
}

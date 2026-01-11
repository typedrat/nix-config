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
  hostHyprlandCfg = osConfig.rat.gui.hyprland or {};

  # Determine monitor configuration: user config if set, else host defaults if enabled
  monitorConfig =
    if (hyprlandCfg.monitors or []) != []
    then hyprlandCfg.monitors
    else if (hyprlandCfg.useHostDefaults or true)
    then hostHyprlandCfg.monitors or []
    else [];

  # Determine workspace configuration: user config if set, else host defaults if enabled
  workspaceConfig =
    if (hyprlandCfg.workspaces or []) != []
    then hyprlandCfg.workspaces
    else if (hyprlandCfg.useHostDefaults or true)
    then hostHyprlandCfg.workspaces or []
    else [];

  tvMonitor = hostHyprlandCfg.tvMonitor or null;
in {
  imports = [
    ./hyprlock
    ./kde
    ./waybar
    ./blur.nix
    ./fcitx5.nix
    ./hyprbars.nix
    ./polkit.nix
    ./pyprland.nix
    ./rofi.nix
    ./smart-gaps.nix
    ./vicinae.nix
    ./wayland-pipewire-idle-inhibit.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (hyprlandCfg.enable or false)) {
    nix.settings = {
      extra-substituters = ["https://hyprland.cachix.org"];
      extra-trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
    };

    home.packages = with pkgs; [
      hyprpolkitagent
      hyprpaper
      swww
      hyprpaper
      mpvpaper
      waytrogen
      hyprpicker
      hyprshot
      playerctl
      libsForQt5.qt5ct
      kdePackages.qt6ct
      nomacs-qt6
      kdePackages.okular
      kdePackages.dolphin
      kdePackages.ark
      kdePackages.kwalletmanager
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;

      package = null;
      portalPackage = null;

      settings = {
        "$main_mod" = "SUPER";

        debug = {
          disable_logs = false;
        };

        monitor = monitorConfig;
        workspace = workspaceConfig;

        bind = [
          "$main_mod&SHIFT,left,workspace,r-1"
          "$main_mod&SHIFT,right,workspace,r+1"
          "$main_mod,s,exec,hyprshot -m window"
          "$main_mod&SHIFT,s,exec,hyprshot -m region"
          "$main_mod,l,exec,loginctl lock-session"
          "$main_mod,f,togglefloating"
          "$main_mod,k,killactive"
          "$main_mod&SHIFT,k,forcekillactive"
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
          "uwsm app -- swww init"
          "uwsm app -- waytrogen --restore"
          "uwsm app -- zsh -c 'STEAM_FRAME_FORCE_CLOSE=1 steam -silent'"
          "uwsm app -- discord --start-minimized"
          "uwsm app -- jellyfin-mpv-shim"
          "uwsm app -- openrgb --startminimized"
          "uwsm app -- pyvizio power on"
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

        misc = {
          enable_anr_dialog = false;
        };
      };

      extraConfig = ''
        windowrule {
          name = float-xdg-desktop-portal-gtk
          match:class = xdg-desktop-portal-gtk
          float = on
        }

        windowrule {
          name = float-blueman
          match:class = .*blueman.*
          float = on
        }

        windowrule {
          name = float-qalculate
          match:class = .*Qalculate.*
          float = on
        }

        windowrule {
          name = float-steam-windows
          match:class = [Ss]team
          match:title = ^((?!Steam).)*$
          float = on
        }

        ${lib.optionalString (tvMonitor != null) ''
          windowrule {
            name = mpv-to-tv
            match:class = mpv
            monitor = ${tvMonitor}
          }
        ''}
      '';
    };

    systemd.user.sessionVariables = {
      HYPRSHOT_DIR = "$HOME/Pictures/Screenshots";
      NIXOS_OZONE_WL = "1";
    };

    services.mako = {
      enable = true;
      settings = {
        defaultTimeout = "5000";
        font = "SF Pro Display 14";
        width = "600";
      };
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
  };
}

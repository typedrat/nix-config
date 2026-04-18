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
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    # Category folders with alternatives
    ./bar
    ./idle
    ./launcher
    ./locker
    ./logout
    ./notifications
    ./wallpaper

    # Simple toggles
    ./bitwarden-resize.nix
    ./blur.nix
    ./fcitx5.nix
    ./hyprbars.nix
    ./kde
    ./polkit.nix
    ./pyprland.nix
    ./smart-gaps.nix
    ./wayland-pipewire-idle-inhibit.nix
  ];

  config = modules.mkIf (guiCfg.enable && hyprlandCfg.enable) {
    nix.settings = {
      extra-substituters = ["https://hyprland.cachix.org"];
      extra-trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    home.packages = with pkgs;
      [
        hyprpolkitagent
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
      ]
      ++ lib.optional osConfig.rat.networking.networkManager.enable networkmanagerapplet;

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

        # Only Hyprland-specific entries here. Generic app autostarts
        # (steam, discord, jellyfin-mpv-shim, openrgb, coolercontrol) are
        # declared once in modules/home-manager/desktop/kde/default.nix via
        # programs.plasma.startup.startupScript, which plasma-manager compiles
        # into an XDG autostart .desktop. systemd-xdg-autostart-generator
        # picks that up in both Plasma and Hyprland+uwsm sessions, so declaring
        # them here too caused double-launches. Steam and Discord hid this
        # with their own single-instance locks; openrgb and jellyfin-mpv-shim
        # don't have singletons, so their second instances were visible.
        #
        # nm-applet is also omitted: its .desktop from the networkmanagerapplet
        # package already ships with `NotShowIn=KDE;GNOME;COSMIC;`, which
        # systemd-xdg-autostart-generator honors. Result: one instance under
        # Hyprland, zero under Plasma (where the native nm widget replaces it).
        exec-once =
          [
            "uwsm app -- waytrogen --restore"
          ]
          ++ lib.optional (tvMonitor != null) "tv-power on";

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
          disable_splash_rendering = true;
          disable_hyprland_logo = true;
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

    services.hyprpaper = {
      enable = true;
      settings = {
        splash = false;
      };
    };

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories =
        [
          ".config/fcitx5"
          ".config/pulse"
          ".local/state/wireplumber"
          ".config/waytrogen"
          ".config/nomacs"
          ".local/share/nomacs"
        ]
        ++ lib.optionals (!osConfig.rat.gui.kde.enable) [
          # Dolphin
          ".local/share/dolphin"
          ".local/share/kfileplaces"

          # Okular
          ".local/share/okular"

          # Recently used files (cross-desktop)
          ".local/share/RecentDocuments"
        ];
    };
  };
}

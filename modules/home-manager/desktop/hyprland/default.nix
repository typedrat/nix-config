{
  config,
  osConfig,
  pkgs,
  lib,
  hlLib,
  ...
}: let
  inherit (lib) modules;
  inherit (hlLib) dsp bind bindOpts execOnce parseMonitor parseWorkspace;
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

  palette = (lib.importJSON "${config.catppuccin.sources.palette}/palette.json").${config.catppuccin.flavor}.colors;
  mkRgb = color: "rgb(${lib.removePrefix "#" palette.${color}.hex})";
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

    # Shared Lua-config helpers (hlLib module arg)
    ./lua-helpers.nix

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

      # Hyprland 0.56 dropped the hyprlang config loader: it only reads
      # ~/.config/hypr/hyprland.lua and ignores hyprland.conf entirely (no
      # fallback), so the whole module emits the Lua config format via the
      # `hl.*` API. Dispatchers, binds, and rules are built through the shared
      # helpers in ./lua-helpers.nix (hlLib) so the sibling modules stay DRY.
      configType = "lua";

      settings = {
        config = {
          debug = {
            disable_logs = false;
          };

          general = {
            resize_on_border = true;
            extend_border_grab_area = 30;
            hover_icon_on_border = true;
            col = {
              inactive_border = mkRgb "crust";
              active_border = mkRgb "overlay2";
            };

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

        monitor = map parseMonitor monitorConfig;
        workspace_rule = map parseWorkspace workspaceConfig;

        bind = [
          (bind "SUPER + SHIFT + left" (dsp.focusWorkspace "r-1"))
          (bind "SUPER + SHIFT + right" (dsp.focusWorkspace "r+1"))
          (bind "SUPER + s" (dsp.exec "hyprshot -m window"))
          (bind "SUPER + SHIFT + s" (dsp.exec "hyprshot -m region"))
          (bind "SUPER + l" (dsp.exec "loginctl lock-session"))
          (bind "SUPER + f" dsp.toggleFloating)
          (bind "SUPER + k" dsp.close)
          (bind "SUPER + SHIFT + k" dsp.forceKill)

          # Media keys stay active while the session is locked.
          (bindOpts "XF86AudioPlay" (dsp.exec "playerctl play-pause") {locked = true;})
          (bindOpts "XF86AudioPrev" (dsp.exec "playerctl previous") {locked = true;})
          (bindOpts "XF86AudioNext" (dsp.exec "playerctl next") {locked = true;})

          (bindOpts "ALT + mouse:272" dsp.drag {mouse = true;})
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
        on =
          [
            (execOnce "uwsm app -- waytrogen --restore")
          ]
          ++ lib.optional (tvMonitor != null) (execOnce "tv-power on");

        window_rule =
          [
            {
              name = "float-xdg-desktop-portal-gtk";
              match = {class = "xdg-desktop-portal-gtk";};
              float = true;
            }
            {
              name = "float-blueman";
              match = {class = ".*blueman.*";};
              float = true;
            }
            {
              name = "float-qalculate";
              match = {class = ".*Qalculate.*";};
              float = true;
            }
            {
              name = "float-steam-windows";
              match = {
                class = "[Ss]team";
                title = "^((?!Steam).)*$";
              };
              float = true;
            }
          ]
          ++ lib.optional (tvMonitor != null) {
            name = "mpv-to-tv";
            match = {class = "mpv";};
            monitor = tvMonitor;
          };
      };
    };

    # catppuccin/nix emits its own `hl.*` color calls; keep it off so this
    # module's explicit catppuccin border colors stay authoritative.
    catppuccin.hyprland.enable = false;

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

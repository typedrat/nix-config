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
  kdeCfg = guiCfg.kde or {};
  hyprlandCfg = guiCfg.hyprland or {};
  launcherVariant = hyprlandCfg.launcher.variant or "rofi";
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  capitalizeFirst = str:
    (lib.toUpper (builtins.substring 0 1 str))
    + (builtins.substring 1 (builtins.stringLength str) str);

  flavorName = capitalizeFirst config.catppuccin.flavor;
  accentName = capitalizeFirst config.catppuccin.accent;

  useVicinae = launcherVariant == "vicinae";
in {
  config = modules.mkIf (
    guiCfg.enable
    && kdeCfg.enable
    && osConfig.rat.gui.kde.enable
  ) {
    programs.plasma = {
      enable = true;
      overrideConfig = false;

      # --- Appearance ---

      workspace = {
        theme = "default";
        lookAndFeel = "Catppuccin-${flavorName}-${accentName}";
        windowDecorations = {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__Catppuccin${flavorName}-Modern";
        };
        splashScreen.theme = "Catppuccin-${flavorName}-${accentName}";
      };

      fonts = {
        general = {
          family = "SF Pro Display";
          pointSize = 13;
        };
        fixedWidth = {
          family = "SF Mono";
          pointSize = 12;
        };
        small = {
          family = "SF Pro Text";
          pointSize = 9;
        };
        toolbar = {
          family = "SF Pro Text";
          pointSize = 11;
        };
        menu = {
          family = "SF Pro Text";
          pointSize = 11;
        };
        windowTitle = {
          family = "SF Pro Display";
          pointSize = 11;
        };
      };

      # --- Panel ---

      panels = [
        {
          location = "bottom";
          height = 32;
          floating = true;
          screen = 1; # DP-1 only (primary monitor)
          widgets = [
            "org.kde.plasma.kickoff"
            "org.kde.plasma.pager"
            "org.kde.plasma.icontasks"
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
            "org.kde.plasma.showdesktop"
          ];
        }
      ];

      # --- Window Manager ---

      kwin = {
        effects = {
          translucency.enable = true;
          blur.enable = true;
        };
      };

      # --- KRunner ---

      krunner = {
        position = "center";
        activateWhenTypingOnDesktop = true;
      };

      # --- Keyboard Shortcuts ---

      shortcuts = {
        # Screenshots (Spectacle replaces hyprshot)
        "org.kde.spectacle.desktop" = {
          ActiveWindowScreenShot = "Meta+S";
          RectangularRegionScreenShot = "Meta+Shift+S";
        };

        # Lock screen
        ksmserver = {
          "Lock Session" = "Meta+L";
        };

        # Workspace navigation
        kwin = {
          "Switch to Previous Desktop" = "Meta+Shift+Left";
          "Switch to Next Desktop" = "Meta+Shift+Right";
          "Close Window" = "Meta+K";
          "Toggle Floating" = "Meta+F";
        };

        # Media controls (KDE handles these natively but set explicitly)
        mediacontrol = {
          playpausemedia = "Media Play";
          previousmedia = "Media Previous";
          nextmedia = "Media Next";
        };
      };

      # --- Custom Hotkeys (arbitrary commands) ---

      hotkeys.commands = lib.mkMerge [
        # Vicinae launcher bindings
        (lib.mkIf useVicinae {
          vicinae-toggle = {
            key = "Meta+Space";
            command = "vicinae toggle";
          };
          vicinae-switch-windows = {
            key = "Meta+B";
            command = "vicinae vicinae://extensions/vicinae/wm/switch-windows";
          };
          vicinae-clipboard = {
            key = "Meta+V";
            command = "vicinae vicinae://extensions/vicinae/clipboard/history";
          };
          vicinae-emoji = {
            key = "Meta+Shift+.";
            command = "vicinae vicinae://extensions/vicinae/core/search-emojis";
          };
        })
      ];

      # --- Startup Scripts ---

      startup.startupScript = lib.mkMerge [
        # Vicinae autostart
        (lib.mkIf useVicinae {
          vicinae = {
            text = "vicinae &";
          };
        })

        # Steam autostart
        (lib.mkIf osConfig.programs.steam.enable {
          steam = {
            text = "STEAM_FRAME_FORCE_CLOSE=1 steam -silent &";
          };
        })

        # Discord autostart
        (lib.mkIf guiCfg.chat.discord.enable {
          discord = {
            text = "discord --start-minimized &";
          };
        })

        # Jellyfin MPV shim
        (lib.mkIf guiCfg.media.enable {
          jellyfin-mpv-shim = {
            text = "jellyfin-mpv-shim &";
          };
        })

        # OpenRGB
        (lib.mkIf osConfig.rat.hardware.openrgb.enable {
          openrgb = {
            text = "openrgb --startminimized &";
          };
        })

        # CoolerControl
        (lib.mkIf osConfig.programs.coolercontrol.enable {
          coolercontrol = {
            text = "coolercontrol &";
          };
        })
      ];

      # --- Misc Config ---

      configFile = {
        kdeglobals = {
          KDE.AnimationDurationFactor = 0.5;
        };
        kwinrc = {
          Windows = {
            # Focus follows mouse, no delay (tiling WM behavior)
            FocusPolicy = "FocusFollowsMouse";
            DelayFocusInterval = 0;
          };
        };
      };
    };

    # Spectacle for screenshots (replaces hyprshot)
    home.packages = with pkgs; [
      kdePackages.spectacle
      playerctl
    ];

    # Screenshot directory
    xdg.userDirs.pictures = "${config.home.homeDirectory}/Pictures";

    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/baloo"
        ".local/share/kactivitymanagerd"
        ".local/share/kwalletd"
        ".local/share/kscreen"
        ".config/kde.org"
        ".config/kdedefaults"
      ];
      files = [
        ".config/kwinrc"
        ".config/plasma-org.kde.plasma.desktop-appletsrc"
        ".config/plasmashellrc"
        ".config/kconf_updaterc"
      ];
    };
  };
}

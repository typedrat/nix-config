{
  config,
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  launcherCfg = hyprlandCfg.launcher or {};
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (launcherCfg.variant or "rofi") == "vicinae"
    ) {
      programs.vicinae = {
        enable = true;
        systemd = {
          enable = true;
          autoStart = true;
        };

        settings = {
          font = {
            size = 10.5;
          };

          popToRootOnClose = true;
          rootSearch = {
            searchFiles = true;
          };

          window = {
            csd = true;
            opacity = 0.625;
            rounding = 10;
          };
        };
      };

      wayland.windowManager.hyprland = {
        settings = {
          bind = [
            "$main_mod, space, exec, vicinae toggle"
            "$main_mod, b, exec, vicinae vicinae://extensions/vicinae/wm/switch-windows"
            "$main_mod, v, exec, vicinae vicinae://extensions/vicinae/clipboard/history"
            "$main_mod&SHIFT, period, exec, vicinae vicinae://extensions/vicinae/core/search-emojis"
          ];
        };

        extraConfig = ''
          layerrule {
            name = vicinae-blur
            match:namespace = vicinae
            blur = on
          }

          layerrule {
            name = vicinae-ignorealpha
            match:namespace = vicinae
            ignore_alpha = 0
          }

          layerrule {
            name = vicinae-noanim
            match:namespace = vicinae
            no_anim = on
          }

          windowrule {
            name = vicinae-no-hyprbars
            match:title = ^Vicinae Launcher$
            hyprbars:no_bar = 1
          }
        '';
      };
    };
}

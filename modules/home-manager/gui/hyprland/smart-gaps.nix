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
  smartGapsCfg = hyprlandCfg.smartGaps or {};
in {
  config =
    modules.mkIf (
      (guiCfg.enable or false)
      && (hyprlandCfg.enable or false)
      && (smartGapsCfg.enable or false)
    ) {
      wayland.windowManager.hyprland = {
        settings = {
          workspace = [
            "w[tv1], gapsout:0, gapsin:0"
            "f[1], gapsout:0, gapsin:0"
          ];

          general = {
            gaps_in = 5;
            gaps_out = 20;
            gaps_workspaces = 0;
            border_size = 2;
          };
        };

        extraConfig = ''
          windowrule {
            name = smart-gaps-tv-bordersize
            match:float = false
            match:workspace = w[tv1]
            border_size = 0
          }

          windowrule {
            name = smart-gaps-tv-rounding
            match:float = false
            match:workspace = w[tv1]
            rounding = 0
          }

          windowrule {
            name = smart-gaps-f1-bordersize
            match:float = false
            match:workspace = f[1]
            border_size = 0
          }

          windowrule {
            name = smart-gaps-f1-rounding
            match:float = false
            match:workspace = f[1]
            rounding = 0
          }
        '';
      };
    };
}

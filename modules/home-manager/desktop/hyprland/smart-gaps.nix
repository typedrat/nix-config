{
  config,
  osConfig,
  lib,
  hlLib,
  ...
}: let
  inherit (lib) modules;
  inherit (hlLib) parseWorkspace;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  smartGapsCfg = hyprlandCfg.smartGaps or {};
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
      && smartGapsCfg.enable
    ) {
      wayland.windowManager.hyprland.settings = {
        workspace_rule = map parseWorkspace [
          "w[tv1], gapsout:0, gapsin:0"
          "f[1], gapsout:0, gapsin:0"
        ];

        config.general = {
          gaps_in = 5;
          gaps_out = 20;
          gaps_workspaces = 0;
          border_size = 2;
        };

        window_rule = [
          {
            name = "smart-gaps-tv-bordersize";
            match = {
              float = false;
              workspace = "w[tv1]";
            };
            border_size = 0;
          }
          {
            name = "smart-gaps-tv-rounding";
            match = {
              float = false;
              workspace = "w[tv1]";
            };
            rounding = 0;
          }
          {
            name = "smart-gaps-f1-bordersize";
            match = {
              float = false;
              workspace = "f[1]";
            };
            border_size = 0;
          }
          {
            name = "smart-gaps-f1-rounding";
            match = {
              float = false;
              workspace = "f[1]";
            };
            rounding = 0;
          }
        ];
      };
    };
}

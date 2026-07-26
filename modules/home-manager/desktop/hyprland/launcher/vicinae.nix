{
  config,
  osConfig,
  lib,
  hlLib,
  ...
}: let
  inherit (lib) modules;
  inherit (hlLib) dsp bind;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  hyprlandCfg = guiCfg.hyprland or {};
  launcherCfg = hyprlandCfg.launcher or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && hyprlandCfg.enable
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

      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        directories = [".local/share/vicinae"];
      };

      wayland.windowManager.hyprland.settings = {
        bind = [
          (bind "SUPER + space" (dsp.exec "vicinae toggle"))
          (bind "SUPER + b" (dsp.exec "vicinae vicinae://extensions/vicinae/wm/switch-windows"))
          (bind "SUPER + v" (dsp.exec "vicinae vicinae://extensions/vicinae/clipboard/history"))
          (bind "SUPER + SHIFT + period" (dsp.exec "vicinae vicinae://launch/core/search-emojis"))
        ];

        layer_rule = [
          {
            match = {namespace = "vicinae";};
            blur = true;
          }
          {
            match = {namespace = "vicinae";};
            ignore_alpha = 0;
          }
          {
            match = {namespace = "vicinae";};
            no_anim = true;
          }
        ];
      };
    };
}

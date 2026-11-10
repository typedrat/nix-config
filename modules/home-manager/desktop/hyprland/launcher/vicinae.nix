{
  config,
  osConfig,
  lib,
  pkgs,
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
        # The audio-control service looks pactl up on PATH, which the systemd
        # user unit doesn't provide.
        package = pkgs.symlinkJoin {
          inherit (pkgs.vicinae) name pname version meta;
          paths = [pkgs.vicinae];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/vicinae \
              --suffix PATH : ${lib.makeBinPath [pkgs.pulseaudio]}
          '';
        };
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
        # The state dir records onboarding completion; losing it brings the
        # welcome window back on every boot. The cache holds the file index,
        # which otherwise gets rebuilt from scratch at each login.
        directories = [
          ".cache/vicinae"
          ".local/share/vicinae"
          ".local/state/vicinae"
        ];
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

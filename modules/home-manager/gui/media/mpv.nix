{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    programs.mpv = {
      enable = true;

      package = pkgs.mpv.override {
        mpv-unwrapped = pkgs.mpv-unwrapped.override {
          vapoursynthSupport = true;
        };
        scripts = with pkgs.mpvScripts; [
          mpris
          mpv-discord
          sponsorblock
          thumbfast
          uosc
        ];
      };

      config = {
        osd-bar = false;
        border = false;
        video-sync = "display-resample";
      };
    };
  };
}

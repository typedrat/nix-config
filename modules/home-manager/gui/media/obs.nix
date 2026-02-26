{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.enable {
      directories = [".config/obs-studio"];
    };
    programs.obs-studio = {
      enable = true;

      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
        obs-pipewire-audio-capture
        obs-vaapi
        obs-vkcapture
        wlrobs
      ];
    };
  };
}

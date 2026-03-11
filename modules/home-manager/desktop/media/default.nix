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
  mediaCfg = guiCfg.media or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    ./easyeffects
    ./mpv.nix
    ./obs.nix
    ./spotify.nix
    ./tauon.nix
  ];

  config = modules.mkIf (guiCfg.enable && mediaCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/jellyfin-mpv-shim"];
    };

    home.packages = with pkgs; [
      jellyfin-media-player
      jellyfin-mpv-shim
      hypnotix
    ];
  };
}

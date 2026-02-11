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
in {
  imports = [
    ./mpv.nix
    ./obs.nix
    ./spotify.nix
    ./tauon.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (mediaCfg.enable or false)) {
    home.packages = with pkgs; [
      jellyfin-media-player
      jellyfin-mpv-shim
      hypnotix
    ];
  };
}

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
    ./spotify.nix
    ./tauon.nix
  ];

  config = modules.mkIf ((guiCfg.enable or false) && (mediaCfg.enable or false)) {
    home.packages = with pkgs; [
      # jellyfin-media-player # Disabled: requires insecure qtwebengine - see NixOS/nixpkgs#437865 and jellyfin/jellyfin-media-player#282
      jellyfin-mpv-shim
    ];
  };
}

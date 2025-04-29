{
  osConfig,
  self',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf osConfig.rat.gui.enable {
    home.packages = with pkgs; [
      # GUI stuff to factor out
      self'.packages.xmage
      jellyfin-mpv-shim
      jellyfin-media-player
      wev
      waypipe
      wineWowPackages.stable
      gamescope
      bottles
      cherry-studio
      gimp
      inkscape
      qalculate-qt
      bitwarden-desktop
    ];
  };
}

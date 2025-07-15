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
      transmission_4-qt6
      self'.packages.xcursor-viewer
      imgbrd-grabber
    ];
  };
}

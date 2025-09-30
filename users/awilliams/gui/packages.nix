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
      bitwarden-desktop
      bottles
      cherry-studio
      gamescope
      gimp3
      imgbrd-grabber
      inkscape
      jellyfin-media-player
      jellyfin-mpv-shim
      qalculate-qt
      self'.packages.xcursor-viewer
      self'.packages.zmk-studio
      transmission_4-qt6
      waypipe
      wev
      wineWowPackages.stable
    ];
  };
}

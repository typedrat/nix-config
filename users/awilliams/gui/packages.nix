{
  osConfig,
  self',
  inputs',
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
      inputs'.claude-desktop.packages.claude-desktop
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

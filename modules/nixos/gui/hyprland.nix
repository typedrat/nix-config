{
  config,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf config.rat.gui.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;

      package = inputs'.hyprland.packages.hyprland;
      portalPackage = inputs'.hyprland.packages.xdg-desktop-portal-hyprland;
    };

    services.displayManager = {
      defaultSession = "hyprland-uwsm";
    };

    security.pam.services.hyprlock = {};

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        config.programs.hyprland.portalPackage
        xdg-desktop-portal-gtk
      ];
    };
  };
}

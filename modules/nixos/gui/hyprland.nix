{
  config,
  inputs',
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib) options types;
in {
  options.rat.gui.hyprland = {
    monitors = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default monitor configuration for this host";
      example = [
        "DP-2,3840x2160@60.0,0x1080,1.0"
        "HDMI-A-1,3840x2160@60.0,960x0,2.0"
      ];
    };

    workspaces = options.mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Default workspace configuration for this host";
      example = [
        "1, monitor:DP-2, persistent=true"
        "2, monitor:DP-2, persistent=true"
      ];
    };
  };

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

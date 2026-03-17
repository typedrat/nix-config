{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkEnableOption;
  cfg = config.rat.gui;
in {
  options.rat.gui.kde = {
    enable = mkEnableOption "KDE Plasma 6 desktop environment";
  };

  config = mkIf (cfg.enable && cfg.kde.enable) {
    services.desktopManager.plasma6.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.kdePackages.xdg-desktop-portal-kde
      ];
      config.KDE = {
        default = ["kde"];
      };
    };
  };
}

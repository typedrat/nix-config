{
  config,
  lib,
  pkgs,
  self',
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.rat.hardware.printing;
in {
  options.rat.hardware.printing.enable =
    mkEnableOption "printing"
    // {
      default = config.rat.gui.enable;
    };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = [
        pkgs.gutenprint
        self'.packages.cups-brother-dcpl2550dw
      ];
    };
  };
}

{
  config,
  lib,
  pkgs,
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
        pkgs.cups-brother-dcpl2550dw
      ];
    };

    hardware.printers = {
      ensureDefaultPrinter = "Brother_DCP-L2550DW";
      ensurePrinters = [
        {
          name = "Brother_DCP-L2550DW";
          description = "Brother DCP-L2550DW";
          deviceUri = "usb://Brother/DCP-L2550DW%20series?serial=U64966C0N935597";
          model = "brother-DCPL2550DW-cups-en.ppd";
        }
      ];
    };
  };
}

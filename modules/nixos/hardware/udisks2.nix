{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.hardware.udisks2.enable =
    mkEnableOption "udisks2"
    // {
      default = config.rat.gui.enable;
    };

  config = mkIf config.rat.hardware.udisks2.enable {
    services.udisks2.enable = true;
  };
}

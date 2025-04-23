{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.sudo.extendedTimeout = mkEnableOption "extended timeout";

  config = mkIf config.rat.sudo.extendedTimeout {
    security.sudo.extraConfig = ''
      Defaults        timestamp_timeout=30
    '';
  };
}

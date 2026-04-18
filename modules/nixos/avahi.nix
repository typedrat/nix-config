{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;

  cfg = config.rat.avahi;
in {
  options.rat.avahi.enable =
    mkEnableOption "Avahi mDNS/DNS-SD"
    // {
      default = true;
    };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;

      ipv4 = true;
      ipv6 = true;

      nssmdns4 = true;
      nssmdns6 = true;

      publish = {
        enable = true;
        userServices = true;
      };
    };
  };
}

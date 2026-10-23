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

      nssmdns4 = true;
      nssmdns6 = true;

      settings = {
        server = {
          use-ipv4 = true;
          use-ipv6 = true;

          # An address record is published for every interface avahi runs on,
          # and the hostname resolves to whichever one answers first. The docker
          # bridge carries 172.17.0.1 on every host that has it, so a client
          # that picks that record is sent to its own bridge instead of this
          # machine.
          deny-interfaces = ["docker0"];
        };

        publish = {
          disable-publishing = false;
          disable-user-service-publishing = false;
          publish-addresses = true;
        };
      };
    };
  };
}

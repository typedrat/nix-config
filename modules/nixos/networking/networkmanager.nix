{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.networking.networkManager;
in {
  options.rat.networking.networkManager = {
    enable = options.mkEnableOption "NetworkManager for network management";
  };

  config = modules.mkIf cfg.enable {
    networking.networkmanager.enable = true;

    # Facter marks every detected NIC useDHCP, which starts dhcpcd on it
    # alongside NetworkManager. On a bridge port that puts the host's address
    # on the port as well as the bridge.
    hardware.facter.detected.dhcp.enable = modules.mkDefault false;
  };
}

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
  };
}

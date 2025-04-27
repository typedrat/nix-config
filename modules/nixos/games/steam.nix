{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.games.steam.enable = mkEnableOption "Steam";

  config = mkIf (config.rat.games.enable && config.rat.games.steam.enable) {
    rat.java.enable = true;

    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;

      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}

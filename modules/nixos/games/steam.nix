{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in {
  options.rat.gaming.steam.enable = mkEnableOption "Steam";

  config = mkIf (config.rat.gaming.enable && config.rat.gaming.steam.enable) {
    rat.java.enable = true;

    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;

      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    environment.systemPackages = with pkgs; [
      protonplus
      protontricks
    ];
  };
}

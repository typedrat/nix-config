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

      # Avalonia apps run through steam-run (e.g. Shin Ryu Mod Manager)
      # dlopen libice/libsm at startup. Ren'Py 7 games' bundled libGLEW needs
      # libxmu/libGLU, or the GL renderer fails to load and it falls back to
      # software rendering.
      extraPackages = with pkgs; [
        libice
        libsm
        libxmu
        libGLU
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
      steamtinkerlaunch
    ];
  };
}

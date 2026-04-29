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

      # GE-Proton (and other custom Proton builds) are managed via ProtonPlus
      # (see environment.systemPackages below). This gives us multi-version
      # flexibility, faster hotfix uptake, and access to Proton-CachyOS / tkg
      # builds that aren't packaged in nixpkgs. Versions install to
      # ~/.local/share/Steam/compatibilitytools.d/ which is persisted by
      # the home-manager gaming module's impermanence config.
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

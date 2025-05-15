{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "hyperion";
  networking.hostId = "0a2e777f";

  rat = {
    boot.loader = "lanzaboote";

    games = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
    };

    gui.enable = true;
    hardware.openrgb.enable = true;
    java.enable = true;
    nix-ld.enable = true;
    polkit.unprivilegedPowerManagement = true;
    security.sudo.extendedTimeout.enable = true;
    virtualisation.docker.enable = true;

    zfs = {
      enable = true;
      rootPool = "zpool";
      rootDataset = "root";
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod;

  networking.hostName = "hyperion";
  networking.hostId = "0a2e777f";

  rat = {
    boot = {
      systemd-boot.enable = false;
      lanzaboote.enable = true;
    };

    games = {
      enable = true;
      animeGameLaunchers = true;
      steam = true;
    };

    gui.enable = true;
    hardware.openrgb.enable = true;
    java.enable = true;
    nix-ld.enable = true;
    polkit.unprivilegedPowerManagement = true;
    sudo.extendedTimeout = true;
    virtualization.docker.enable = true;
    zfs.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

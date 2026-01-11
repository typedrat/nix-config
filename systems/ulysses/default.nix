{
  pkgs,
  ...
}: {
  imports = [
    ./disko-config.nix
    ./nvidia.nix
    ./superio.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "ulysses";
  networking.hostId = "7e104ef9";

  rat = {
    boot = {
      loader = "lanzaboote";
      secureBoot.autoEnrollKeys = true;
    };

    gui = {
      enable = true;
      hyprland = {
        monitors = [
          "desc:Acer Technologies XB321HK #ASM9xe8P/tXd,3840x2160@60.0,0x1080,1.0"
          "desc:DENON Ltd. DENON-AVR 0x01010101,3840x2160@60.0,960x0,2.0"
        ];
        workspaces = [
          "1, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "2, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "3, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "4, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "5, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "6, monitor:desc:Acer Technologies XB321HK #ASM9xe8P/tXd, persistent=true"
          "name:tv, monitor:desc:DENON Ltd. DENON-AVR 0x01010101, persistent=true"
        ];
      };
    };

    theming.fonts.enableGoogleFonts = false;
    polkit.unprivilegedPowerManagement = true;
    security.sudo.extendedTimeout.enable = true;
    virtualisation.docker.enable = true;

    games = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
    };

    hardware.openrgb.enable = true;
    hardware.usbmuxd.enable = true;
    java.enable = true;
    nix-ld.enable = true;

    impermanence = {
      enable = true;
      zfs.enable = true;
    };

    zfs = {
      enable = true;
      rootPool = "zpool";
      rootDataset = "local/root";
    };

    # User configuration (system-specific overrides)
    users.awilliams = {
      enable = true;
      gui = {
        enable = true;
        hyprland.launcher = "vicinae";
        terminal.ghostty.enable = true;
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

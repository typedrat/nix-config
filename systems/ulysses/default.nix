{
  pkgs,
  ...
}: {
  imports = [
    ./disko-config.nix
    ./nvidia.nix
  ];

  facter.reportPath = ./facter.json;

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
        # TODO: Configure monitors for your setup
        # Use `hyprctl monitors` to find monitor names and resolutions
        monitors = [
          # "DP-1,1920x1080@60.0,0x0,1.0"
        ];
        workspaces = [
          # "1, monitor:DP-1, persistent=true"
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
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

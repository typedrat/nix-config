{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./comfyui
    ./disko-config.nix
    ./nvidia.nix
    ./superio.nix
  ];

  hardware.facter.reportPath = ./facter.json;

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  boot.supportedFilesystems = ["ntfs"];

  # Windows drive (WD SN750 500GB)
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-id/nvme-WDS500G3X0C-00SJG0_21025A800309-part3";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=${toString config.users.users.awilliams.uid}"
      "nofail"
      "x-gvfs-show"
      "x-gvfs-name=Windows"
      "x-gvfs-icon=drive-harddisk"
    ];
  };

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
        primaryMonitor = "DP-3";
        tvMonitor = "HDMI-A-1";
        monitors = [
          "DP-3,3840x2160@60.0,0x1080,1.0"
          "HDMI-A-1,3840x2160@60.0,960x0,2.0"
        ];
        workspaces = [
          "1, monitor:DP-3, persistent=true"
          "2, monitor:DP-3, persistent=true"
          "3, monitor:DP-3, persistent=true"
          "4, monitor:DP-3, persistent=true"
          "5, monitor:DP-3, persistent=true"
          "6, monitor:DP-3, persistent=true"
          "name:tv, monitor:HDMI-A-1, persistent=true"
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
      extraGroups = ["comfyui"];
      gui = {
        enable = true;
        hyprland.launcher = "vicinae";
        terminal.ghostty.enable = true;
        productivity.krita = {
          enable = true;
          aiDiffusion.enable = true;
        };
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

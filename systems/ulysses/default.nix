{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./alsa-ucm-conf.nix
    # ./comfyui
    ./disko-config.nix
    ./superio.nix
    ./wireplumber.nix
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
      loader = "limine";
      memtest86.enable = true;
      limine.secureBoot = {
        validateChecksums = true;
        enrollConfig = true;
      };
      windows = {
        enable = true;
        title = "Windows 11";
        # Windows ESP on WD SN750 (/dev/nvme0n1p1)
        efiPartition = "guid://a2b0ff18-ff5e-4783-b72d-323241b76611";
      };
    };

    hardware.nvidia = {
      enable = true;
      cuda.enable = true;
    };

    gui = {
      enable = true;
      hyprland = {
        primaryMonitor = "DP-1";
        tvMonitor = "HDMI-A-1";
        monitors = [
          "DP-1,3840x2160@60.0,0x1080,1.0"
          "HDMI-A-1,1920x1080@60.0,960x0,1.0"
        ];
        workspaces = [
          "1, monitor:DP-1, persistent=true"
          "2, monitor:DP-1, persistent=true"
          "3, monitor:DP-1, persistent=true"
          "4, monitor:DP-1, persistent=true"
          "5, monitor:DP-1, persistent=true"
          "6, monitor:DP-1, persistent=true"
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
        productivity = {
          freecad.enable = false;
          krita = {
            enable = true;
            aiDiffusion.enable = true;
          };
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    llama-cpp
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

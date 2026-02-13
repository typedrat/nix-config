{
  config,
  inputs',
  lib,
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
  # Prevent hwinfo/nixos-facter from misdetecting as laptop (battery module loaded = laptop heuristic)
  boot.blacklistedKernelModules = ["battery"];
  # Don't load amdgpu in initrd - it changes monitor enumeration order
  hardware.facter.detected.boot.graphics.kernelModules = lib.mkForce ["nvidia"];

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
    # Ryzen 9 9950X3D
    hardware.cpu = {
      cores = 16;
      threads = 32;
    };

    deployment = {
      enable = true;
      flakeRef = "typedrat/nix-config/0.1";
      operation = "boot"; # Safer for workstation - applies on next reboot
      webhook.enable = true;
      polling.enable = true;
      rollback.enable = true;
      tunnel.enable = true;
    };

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
        efiPartition = "guid(a2b0ff18-ff5e-4783-b72d-323241b76611)";
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
    hardware.securityKey.enable = true;
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
      cli = {
        enable = true;
        comfy-cli.enable = true;
      };
      gui = {
        enable = true;
        hyprland = {
          launcher.variant = "vicinae";
          idle.mediaInhibit = true;
          wallpaper.enable = true;
          logout.enable = true;
          blur.enable = true;
          hyprbars.enable = true;
          kde.enable = true;
          pyprland.enable = true;
          smartGaps.enable = true;
        };
        terminal.ghostty.enable = true;
        productivity = {
          krita = {
            enable = true;
            aiDiffusion.enable = true;
          };
        };
      };
    };
  };

  environment.systemPackages = [
    inputs'.llama-cpp.packages.cuda
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}

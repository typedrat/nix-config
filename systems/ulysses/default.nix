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

  # --- Networking ---

  networking.hostName = "ulysses";
  networking.hostId = "7e104ef9";

  # --- Boot ---

  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  boot.supportedFilesystems = ["ntfs"];
  # Prevent hwinfo/nixos-facter from misdetecting as laptop (battery module loaded = laptop heuristic)
  boot.blacklistedKernelModules = ["battery"];

  # --- Hardware ---

  hardware.facter.reportPath = ./facter.json;
  # Don't load amdgpu in initrd - it changes monitor enumeration order
  hardware.facter.detected.boot.graphics.kernelModules = lib.mkForce ["nvidia"];

  # --- Extra filesystems ---

  # Hyperion home backup (ZFS dataset received from old system)
  fileSystems."/mnt/hyperion-home" = {
    device = "zpool/safe/hyperion-home";
    fsType = "zfs";
    options = ["nofail"];
  };

  # Not currently installed.
  # # Windows drive (WD SN750 500GB)
  # fileSystems."/mnt/windows" = {
  #   device = "/dev/disk/by-id/nvme-WDS500G3X0C-00SJG0_21025A800309-part3";
  #   fsType = "ntfs-3g";
  #   options = [
  #     "rw"
  #     "uid=${toString config.users.users.awilliams.uid}"
  #     "nofail"
  #     "x-gvfs-show"
  #     "x-gvfs-name=Windows"
  #     "x-gvfs-icon=drive-harddisk"
  #   ];
  # };

  # --- Extra packages ---

  environment.systemPackages = [
    inputs'.llama-cpp.packages.cuda
  ];

  # --- rat.* configuration ---

  rat = {
    # Boot
    boot = {
      loader = "limine";
      memtest86.enable = true;
      limine.secureBoot = {
        validateChecksums = true;
        enrollConfig = true;
      };
      # windows = {
      #   enable = true;
      #   title = "Windows 11";
      #   # Windows ESP on WD SN750 (/dev/nvme0n1p1)
      #   efiPartition = "guid(a2b0ff18-ff5e-4783-b72d-323241b76611)";
      # };
    };

    # Hardware
    hardware = {
      # Ryzen 9 9950X3D
      cpu = {
        cores = 16;
        threads = 32;
      };
      nvidia = {
        enable = true;
        cuda.enable = true;
      };
      openrgb.enable = true;
      topping-e2x2.enable = true;
      securityKey.enable = true;
      usbmuxd.enable = true;
    };

    # Storage
    zfs = {
      enable = true;
      rootPool = "zpool";
      rootDataset = "local/root";
    };
    impermanence = {
      enable = true;
      zfs.enable = true;
    };

    # Deployment
    deployment = {
      enable = true;
      flakeRef = "typedrat/nix-config/0.1";
      operation = "boot"; # Safer for workstation - applies on next reboot
      webhook.enable = true;
      polling.enable = true;
      rollback.enable = true;
      tunnel.enable = true;
    };

    # GUI
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

    # Games
    games = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
    };

    # Software
    java.enable = true;
    nix-ld.enable = true;
    virtualisation.docker.enable = true;

    # Security
    polkit.unprivilegedPowerManagement = true;
    security.sudo.extendedTimeout.enable = true;

    # User configuration
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

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}

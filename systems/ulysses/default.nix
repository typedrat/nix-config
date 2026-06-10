{
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
  # Also blacklist amdgpu - this system uses NVIDIA exclusively, and amdgpu being loaded
  # affects monitor enumeration order.
  boot.blacklistedKernelModules = [
    "battery"
    "amdgpu"
  ];

  # --- Session variables ---

  # Force GLVND to use the NVIDIA EGL vendor library. Without this, applications
  # may pick up a non-NVIDIA EGL implementation when multiple are present.
  environment.sessionVariables = {
    __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json";
  };

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

  fileSystems."/home/awilliams/mnt/hyperion-home" = {
    device = "/mnt/hyperion-home/awilliams";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
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

  # --- udev rules ---

  # Mionix Naos PRO - grant user access to hidraw devices
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="22d4", ATTRS{idProduct}=="132b", MODE="0666"
  '';

  # --- rat.* configuration ---

  rat = {
    # Networking
    networking.networkManager.enable = true;
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

      # NVIDIA RTX 5090
      gpu = {
        vendor = "nvidia";
        vram = 32;
      };

      nvidia = {
        enable = true;
        cuda.enable = true;
      };
      openrgb.enable = true;
      topping-e2x2.enable = true;
      securityKey.enable = true;
      usbmuxd.enable = true;
      nintendoSwitch.rcm.enable = true;
    };

    # Storage
    zfs = {
      enable = true;
      rootPool = "zpool";
      rootDataset = "local/root";
    };
    impermanence = {
      enable = true;
      home.enable = true;
      zfs.enable = true;
      zfs.homeDataset = "local/home";
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
      browsers.chromium.enable = true;
      kde.enable = true;
      hyprland = {
        primaryMonitor = "DP-1";
        tvMonitor = "HDMI-A-1";
        monitors = [
          # vrr=1: always-on VRR (G-SYNC Compatible / FreeSync).
          # The S2725QS has a 48-120Hz VRR range. Always-on gives smoother
          # desktop scrolling and reliable VRR in borderless-windowed games
          # (where vrr=2's fullscreen detection can miss). Drop to vrr=2 if
          # this specific panel turns out to flicker on the desktop.
          "DP-1,3840x2160@120.0,0x1080,1.0,vrr,1"
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

    # Gaming
    gaming = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
      sunshine = {
        enable = true;
        users = ["awilliams"];
        encoder = "nvenc"; # RTX 5090
        # Streams a dedicated headless display (default name "sunshine") so the
        # physical monitors stay on your work while you game remotely.
      };
    };

    # Software
    flatpak.enable = true;
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
        ai.peon-ping.enable = true;
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
        terminals.ghostty.enable = true;
        productivity.handy.enable = true;
        productivity.krita = {
          enable = true;
          aiDiffusion.enable = true;
        };
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}

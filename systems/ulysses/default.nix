{
  lib,
  pkgs,
  ...
}: {
  imports = [
    # ./comfyui
    ./dell-no-audio
    ./disko-config.nix
    ./superio.nix
    ./tank.nix
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

  # MediaTek MT7927 / MT6639 (Filogic 380) WiFi 7 + Bluetooth combo card.
  # Builds out-of-tree patched btusb/btmtk (for BT USB 0489:e110, not yet in
  # mainline) and patched mt7925e/mt7921e (320MHz EHT fixes), plus extracts the
  # BT/WiFi firmware. This replaces the external Realtek RTL8761B dongle, whose
  # USB autosuspend was severing the GuliKit controller's Bluetooth link
  # ~1 minute into use. disableAspm fixes a PCIe ASPM "stuck upload" issue.
  rat.hardware.mt7927 = {
    enable = true;
    enableWifi = true;
    enableBluetooth = true;
    disableAspm = true;
  };

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

  # --- TLS certificates ---

  # Vast.ai Jupyter CA — signs the per-instance TLS certs used to reach a
  # rented instance's Jupyter/console over HTTPS. Trusting the root lets
  # browsers and curl validate those connections.
  security.pki.certificateFiles = [
    (pkgs.fetchurl {
      url = "https://console.vast.ai/static/jvastai_root.cer";
      hash = "sha256-QGjq6SSC8EWhFZtStgQULMLH5Cena/jPIHDneZeOlQc=";
    })
  ];

  # --- udev rules ---

  # Mionix Naos PRO - grant user access to hidraw devices
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="22d4", ATTRS{idProduct}=="132b", MODE="0666"
  '';

  # --- rat.* configuration ---

  # --- Telemetry ---

  # Extra node_exporter collectors aimed at the lock-ups this machine has been
  # having. `processes` surfaces tasks piling up in uninterruptible sleep,
  # `interrupts` catches an IRQ storm, and `buddyinfo`/`zoneinfo` show memory
  # fragmenting to the point where allocations start stalling. hwmon and edac
  # are on by default and cover thermals and ECC.
  services.prometheus.exporters.node.enabledCollectors = [
    "pressure"
    "processes"
    "interrupts"
    "buddyinfo"
    "zoneinfo"
  ];

  # Turn a lock-up into a panic. A wedged machine is already unrecoverable, so
  # there is nothing left to protect by staying up, and a panic buys a stack
  # trace: netpoll runs in polling mode and keeps working in panic context, so
  # the trace goes out over netconsole, and the EFI pstore backend keeps a copy
  # that systemd-pstore archives on the way back up.
  #
  # hung_task_panic and panic_on_rcu_stall stay off. Both fire on conditions
  # this machine can plausibly survive under heavy IO, and a false panic costs
  # more than the trace is worth.
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.hardlockup_panic" = 1;
    # The one to back out first if this machine starts panicking under load
    # rather than at the moment it would have hung.
    "kernel.softlockup_panic" = 1;

    # Dump every CPU, not just the stuck one: a lock-up is usually about what
    # some *other* core is holding.
    "kernel.hardlockup_all_cpu_backtrace" = 1;
    "kernel.softlockup_all_cpu_backtrace" = 1;

    # Task states and memory info alongside the trace, which is the difference
    # between knowing a task blocked and knowing what it blocked on.
    "kernel.panic_print" = 3;

    "kernel.panic" = 30;

    # Plymouth drops console_loglevel to 0 for a clean splash, which silences
    # every console — netconsole included. panic() calls console_verbose() and
    # so gets through regardless, but the warnings leading up to a hang would
    # not, and those are the ones worth reading. Overriding only the sysctl
    # leaves the boot-time `loglevel=` parameter alone, so the splash stays
    # clean and the console only turns verbose once userspace is up.
    "kernel.printk" = 7;
  };

  # Recovery only, not diagnosis: the SP5100 TCO timer exposes no pretimeout
  # governor, so it resets without a chance to panic first. It earns its place
  # for the hangs that trip none of the detectors above.
  systemd.settings.Manager.RuntimeWatchdogSec = "60s";

  rat = {
    # Networking
    networking.networkManager.enable = true;
    # Boot
    boot = {
      loader = "limine";
      limine.secureBoot = {
        enable = true;
        validateChecksums = true;
        enrollConfig = true;
      };
      windows = {
        enable = true;
        title = "Windows 11";
      };
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
        package = "latest";
        cuda.enable = true;
        profiling.enable = true;
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
    backup = {
      enable = true;
      datasets = [
        "zpool/safe/persist"
        "zpool/safe/hyperion-home"
      ];
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

    # Telemetry, collected by iserlohn
    services = {
      prometheus.push.target = "iserlohn.lan";
      remoteSyslog.forwardTo = "iserlohn.lan";
      netconsole.forwardTo = "iserlohn.lan";
    };

    # Software
    flatpak.enable = true;
    java.enable = true;
    nix-ld.enable = true;
    virtualisation.docker = {
      enable = true;
      nvidia.enable = true; # RTX 5090 GPU access in containers (CDI)
    };

    # Security
    polkit.unprivilegedPowerManagement = true;
    security.sudo.extendedTimeout.enable = true;

    # User configuration
    users.awilliams = {
      enable = true;
      extraGroups = [
        "comfyui"
        "ydotool"
      ];
      cli = {
        enable = true;
        ai.peon-ping.enable = true;
      };
      gui = {
        enable = true;
        gaming.eden.enable = true;
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
        productivity.handy.enable = true;
        productivity.krita = {
          enable = true;
          aiDiffusion.enable = true;
        };
        terminals.ghostty.enable = true;
      };
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}

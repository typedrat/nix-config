# Minimal air-gapped live environment for security key/GPG key generation
#
# Build with: nix build .#nixosConfigurations.keygen-live.config.system.build.isoImage
#
# Based on https://github.com/drduh/YubiKey-Guide
#
# Security features:
# - No networking (disabled at service and module level)
# - Ephemeral GNUPGHOME in /run (keys never touch disk)
# - Shell history disabled
#
# Backup capabilities:
# - Printing for paperkey backups
# - QR code generation (qrencode) and reading (zbar/zbarcam)
# - Webcam access for scanning QR codes
{
  lib,
  pkgs,
  self',
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];

  # ISO configuration
  isoImage = {
    isoName = "keygen-live.iso";
    volumeID = "KEYGEN";
    squashfsCompression = "zstd"; # Faster builds than xz
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  swapDevices = [];

  boot = {
    tmp.cleanOnBoot = true;
    kernel.sysctl = {
      "kernel.unprivileged_bpf_disabled" = 1;
    };

    # Disable network in initrd
    initrd.network.enable = false;

    # Blacklist bluetooth (can be used for networking)
    blacklistedKernelModules = [
      "btusb"
      "bluetooth"
    ];
  };

  networking = {
    hostName = "keygen-live";

    # Comprehensive network isolation
    useDHCP = false;
    useNetworkd = false;
    resolvconf.enable = false;
    dhcpcd.enable = false;
    dhcpcd.allowInterfaces = [];
    interfaces = {};
    wireless.enable = false;
    networkmanager.enable = lib.mkForce false;

    # Keep firewall enabled to block any accidental traffic
    firewall.enable = true;
  };

  services = {
    # Smart card daemon for security key communication
    pcscd.enable = true;
    udev.packages = [pkgs.yubikey-personalization];

    # Auto-login at console
    getty.autologinUser = "nixos";

    # Disable unnecessary services
    openssh.enable = false;
    udisks2.enable = false;
    avahi.enable = false;

    # Enable printing for paperkey backups
    printing = {
      enable = true;
      drivers = [
        pkgs.gutenprint
        self'.packages.cups-brother-dcpl2550dw
      ];
    };
  };

  programs = {
    ssh.startAgent = false;
    gnupg = {
      dirmngr.enable = true;
      agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryPackage = pkgs.pinentry-curses;
      };
    };
  };

  # Live user configuration
  users.users = {
    nixos = {
      isNormalUser = true;
      extraGroups = ["wheel" "video"];
      initialHashedPassword = "";
    };
    root.initialHashedPassword = "";
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  environment.systemPackages = with pkgs; [
    # GPG and security key tools
    gnupg
    pinentry-curses
    pcsc-tools
    ccid
    opensc

    # YubiKey tools
    yubikey-manager
    yubikey-personalization
    yubico-piv-tool

    # Key backup tools
    paperkey
    pgpdump

    # QR code generation and reading
    qrencode # Generate QR codes
    zbar # Read QR codes (includes zbarcam for webcam)

    # Webcam utilities
    v4l-utils
    fswebcam # Simple webcam capture

    # Password generation
    diceware
    pwgen

    # Partition tools (for encrypted backup media)
    parted
    cryptsetup

    # Utilities
    vim
    tmux
    htop
    file
    tree
    usbutils
    pciutils
    feh # Image viewer for QR codes
  ];

  # Disable shell history and use ephemeral GNUPGHOME
  environment.interactiveShellInit = ''
    unset HISTFILE
    export GNUPGHOME="/run/user/$(id -u)/gnupg"
    if [ ! -d "$GNUPGHOME" ]; then
      echo "Creating \$GNUPGHOME..."
      install --verbose -m=0700 --directory="$GNUPGHOME"
    fi
    echo "\$GNUPGHOME is \"$GNUPGHOME\""
  '';

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Allow unfree Brother printer driver
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "cups-brother-dcpl2550dw"
    ];

  system.stateVersion = "25.05";
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types modules;
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.rat.boot;
  impermanenceCfg = config.rat.impermanence;

  # Whether secure boot is active (always for lanzaboote, optional for limine)
  secureBootActive =
    cfg.loader
    == "lanzaboote"
    || (cfg.loader == "limine" && cfg.limine.secureBoot.enable);
  # Bootloaders that use systemd-boot under the hood
in {
  imports = [
    ./lanzaboote.nix
    ./limine.nix
  ];

  options.rat.boot = {
    loader = mkOption {
      default = "systemd-boot";
      type = types.enum ["systemd-boot" "lanzaboote" "limine"];
      description = "The bootloader to use";
    };

    maxGenerations = mkOption {
      type = types.int;
      default = 10;
      description = "Maximum number of generations to keep in the boot menu";
    };

    secureBoot = {
      pkiBundle = mkOption {
        type = types.path;
        default = "/var/lib/sbctl";
        description = "Path to the Secure Boot PKI bundle used by sbctl";
      };

      autoEnrollKeys = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to automatically enroll Secure Boot keys on first boot";
      };
    };

    memtest86 = {
      enable = mkEnableOption "Memtest86+ memory testing program in the boot menu";
    };

    windows = {
      enable = mkEnableOption "Windows dual-boot entry";

      title = mkOption {
        type = types.str;
        default = "Windows";
        description = "Title to display in the boot menu";
      };

      efiDeviceHandle = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          UEFI device handle for systemd-boot when Windows is on a separate ESP (e.g., "FS1").
          Find this by booting into UEFI Shell and running "map -c",
          then checking which FSx contains EFI/Microsoft/Boot.

          Note: Lanzaboote does not support this - Windows must be on the same ESP
          (leave this as null when using lanzaboote).
        '';
      };

      efiPath = mkOption {
        type = types.str;
        default = "/EFI/Microsoft/Boot/bootmgfw.efi";
        description = "Path to the Windows EFI bootloader";
      };

      efiPartition = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Limine resource string for the partition containing Windows.
          When null (default), uses "boot()" for the same ESP as Limine.
          For a different partition, specify:
          - "boot(n)" for the nth partition on the boot drive
          - "uuid://XXXX-XXXX" for a partition by filesystem UUID
          - "guid://XXXX-XXXX-XXXX-XXXX" for a partition by GPT GUID

          Only used with the Limine bootloader.
        '';
      };
    };
  };

  config = modules.mkMerge [
    # Common configuration for all bootloaders
    {
      boot.loader.timeout = 1;
      boot.loader.efi.canTouchEfiVariables = true;
    }

    # systemd-boot configuration
    (modules.mkIf (cfg.loader == "systemd-boot") {
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = cfg.maxGenerations;
      };
    })

    # Windows dual-boot for systemd-boot with separate ESP (efiDeviceHandle required)
    (modules.mkIf (cfg.loader == "systemd-boot" && cfg.windows.enable && cfg.windows.efiDeviceHandle != null) {
      assertions = [
        {
          assertion = cfg.windows.efiPartition == null;
          message = "rat.boot.windows.efiPartition is only used with Limine, not systemd-boot";
        }
      ];

      boot.loader.systemd-boot = {
        edk2-uefi-shell.enable = true;
        edk2-uefi-shell.sortKey = "z_shell";
        windows."windows" = {
          inherit (cfg.windows) title efiDeviceHandle;
          sortKey = "y_windows";
        };
      };
    })

    # Windows dual-boot for systemd-boot with same ESP (auto-detected, no config needed)
    (modules.mkIf (cfg.loader == "systemd-boot" && cfg.windows.enable && cfg.windows.efiDeviceHandle == null) {
      assertions = [
        {
          assertion = cfg.windows.efiPartition == null;
          message = "rat.boot.windows.efiPartition is only used with Limine, not systemd-boot";
        }
      ];
      # systemd-boot auto-detects Windows on the same ESP, no explicit config needed
    })

    # Windows dual-boot for lanzaboote (requires Windows on same ESP, auto-detected)
    (modules.mkIf (cfg.loader == "lanzaboote" && cfg.windows.enable) {
      assertions = [
        {
          assertion = cfg.windows.efiDeviceHandle == null;
          message = "rat.boot.windows.efiDeviceHandle must be null for lanzaboote - Windows must be on the same ESP";
        }
        {
          assertion = cfg.windows.efiPartition == null;
          message = "rat.boot.windows.efiPartition is only used with Limine, not lanzaboote";
        }
      ];
      # systemd-boot (used by lanzaboote) auto-detects Windows on the same ESP
    })

    # Memtest86+ for systemd-boot/lanzaboote
    (modules.mkIf ((cfg.loader == "systemd-boot" || cfg.loader == "lanzaboote") && cfg.memtest86.enable) {
      boot.loader.systemd-boot.memtest86.enable = true;
    })

    # Common secure boot configuration (sbctl package and impermanence)
    (modules.mkIf secureBootActive {
      environment.systemPackages = [pkgs.sbctl];
    })

    (modules.mkIf (secureBootActive && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [cfg.secureBoot.pkiBundle];
      };
    })
  ];
}

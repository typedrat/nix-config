{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) options modules types;
  cfg = config.rat.boot;
in {
  options.rat.boot.limine = {
    enableEditor = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow editing boot entries before booting them";
    };

    efiSupport = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install limine for EFI systems";
    };

    biosSupport = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to install limine for BIOS systems";
    };

    biosDevice = options.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Device to install the BIOS version of limine on";
    };

    extraConfig = options.mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration to prepend to limine.conf";
    };

    extraEntries = options.mkOption {
      type = types.lines;
      default = "";
      description = "Extra entries to append to limine.conf";
    };

    secureBoot = {
      enable = options.mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Secure Boot support for Limine";
      };

      validateChecksums = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to validate file checksums before booting";
      };

      panicOnChecksumMismatch = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether checksum validation failure should be a fatal error at boot";
      };

      enrollConfig = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enroll the config for Secure Boot";
      };
    };

    style = {
      wallpapers = options.mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of wallpaper images for the boot menu (random selection)";
      };

      wallpaperStyle = options.mkOption {
        type = types.enum ["centered" "stretched" "tiled"];
        default = "stretched";
        description = "How to display the wallpaper";
      };

      backdrop = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Background color in RRGGBB format";
      };
    };
  };

  config = modules.mkMerge [
    (modules.mkIf (cfg.loader == "limine") {
      assertions = [
        {
          assertion = !cfg.secureBoot.autoEnrollKeys;
          message = "rat.boot.secureBoot.autoEnrollKeys is not supported with Limine - enroll keys manually with sbctl";
        }
      ];

      boot.loader.limine = {
        enable = true;
        inherit (cfg) maxGenerations;
        inherit (cfg.limine) enableEditor efiSupport biosSupport extraConfig;

        style = {
          inherit (cfg.limine.style) wallpapers wallpaperStyle backdrop;
        };
      };
    })

    # User-provided extra entries
    (modules.mkIf (cfg.loader == "limine" && cfg.limine.extraEntries != "") {
      boot.loader.limine.extraEntries = cfg.limine.extraEntries;
    })

    # Windows dual-boot for Limine (via EFI chainload)
    (modules.mkIf (cfg.loader == "limine" && cfg.windows.enable) {
      assertions = [
        {
          assertion = cfg.windows.efiDeviceHandle == null;
          message = "rat.boot.windows.efiDeviceHandle is only used with systemd-boot, not Limine - use efiPartition instead";
        }
      ];

      boot.loader.limine.extraEntries = let
        partition =
          if cfg.windows.efiPartition != null
          then cfg.windows.efiPartition
          else "boot()";
      in ''
        /${cfg.windows.title}
        protocol: efi
        path: ${partition}:${cfg.windows.efiPath}
      '';
    })

    # Memtest86+ for Limine
    (modules.mkIf (cfg.loader == "limine" && cfg.memtest86.enable) {
      boot.loader.limine = {
        additionalFiles."EFI/memtest86plus/mt86plus.efi" = "${pkgs.memtest86plus}/mt86plus.efi";
        extraEntries = let
          memtestHash = lib.strings.trim (builtins.readFile (pkgs.runCommand "memtest-blake2b" {} ''
            ${lib.getExe' pkgs.coreutils "b2sum"} ${pkgs.memtest86plus}/mt86plus.efi | cut -d' ' -f1 > $out
          ''));
        in ''
          /Memtest86+
          protocol: efi
          path: boot():/EFI/memtest86plus/mt86plus.efi#${memtestHash}
        '';
      };
    })

    # BIOS device configuration
    (modules.mkIf (cfg.loader == "limine" && cfg.limine.biosSupport && cfg.limine.biosDevice != null) {
      boot.loader.limine.biosDevice = cfg.limine.biosDevice;
    })

    # Secure Boot configuration
    (modules.mkIf (cfg.loader == "limine" && cfg.limine.secureBoot.enable) {
      boot.loader.limine = {
        secureBoot.enable = true;
        inherit (cfg.limine.secureBoot) validateChecksums panicOnChecksumMismatch enrollConfig;
      };
    })
  ];
}

{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat;
  usesSystemdBoot = cfg.boot.loader == "systemd-boot" || cfg.boot.loader == "lanzaboote";
  # NVIDIA provides its own DRM framebuffer via nvidia-drm.fbdev=1. simpledrm
  # races against it: simpledrm binds the EFI GOP fb at ~t=1.4s, then nvidia-drm
  # replaces fb0 at ~t=4s and fbcon takes over the console, overdrawing the
  # Plymouth splash with the text VT for the rest of the boot.
  usesNvidia = cfg.hardware.nvidia.enable or false;
in {
  options.rat.gui.plymouth.enable =
    mkEnableOption "plymouth"
    // {
      default = true;
    };

  config = mkIf (cfg.gui.enable && cfg.gui.plymouth.enable) (mkMerge [
    {
      boot = {
        plymouth = {
          enable = true;
          extraConfig = ''
            DeviceScale=1
          '';
        };

        consoleLogLevel = 0;
        initrd = {
          verbose = false;
          systemd.enable = true;
        };
        kernelParams = [
          "quiet"
          "boot.shell_on_fail"
          "loglevel=3"
          "rd.systemd.show_status=false"
          "rd.udev.log_level=3"
          "udev.log_priority=3"
        ];
      };
    }

    # Use simpledrm for Plymouth on non-NVIDIA systems (provides early framebuffer from EFI GOP)
    (mkIf (!usesNvidia) {
      boot.kernelParams = ["plymouth.use-simpledrm"];
    })

    # On NVIDIA systems, prevent the kernel from binding simpledrm/efifb/vesafb
    # to the EFI GOP framebuffer in early boot. Otherwise simpledrm grabs fb0
    # at ~t=1.4s, Plymouth paints on it, and then nvidia-drm (loading ~t=4s
    # later via initrd kernel modules) replaces fb0 — at which point fbcon
    # takes over the console and overdraws the splash with the text VT for
    # the rest of the boot. Disabling these drivers makes nvidia-drm the only
    # framebuffer provider, so Plymouth waits ~3s for it and then paints
    # cleanly with no handoff.
    (mkIf usesNvidia {
      boot.kernelParams = [
        "video=efifb:off"
        "video=simplefb:off"
        "video=vesafb:off"
      ];
    })

    # systemd-boot specific configuration
    (mkIf usesSystemdBoot {
      boot.loader.systemd-boot.consoleMode = "auto";
    })
  ]);
}

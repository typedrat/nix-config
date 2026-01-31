{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.rat;
  usesSystemdBoot = cfg.boot.loader == "systemd-boot" || cfg.boot.loader == "lanzaboote";
  # NVIDIA provides its own DRM framebuffer via nvidia-drm.fbdev=1, so simpledrm
  # is not needed and actually prevents Plymouth from finding the framebuffer.
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

    # systemd-boot specific configuration
    (mkIf usesSystemdBoot {
      boot.loader.systemd-boot.consoleMode = "auto";
    })
  ]);
}

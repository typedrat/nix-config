{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.rat.hardware.nvidia;
in {
  options.rat.hardware.nvidia = {
    enable = mkEnableOption "NVIDIA GPU support with Hyprland/Wayland optimizations";

    open = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to use the open source kernel modules.
        Required for 50xx series cards, recommended for Turing (16xx/20xx) and newer.
      '';
    };

    powerManagement.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable NVIDIA power management for suspend/resume support";
    };

    cuda.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable CUDA support in nixpkgs";
    };
  };

  config = mkIf cfg.enable {
    # Core NVIDIA driver configuration
    hardware.nvidia = {
      inherit (cfg) open;
      nvidiaPersistenced = true;
      modesetting.enable = true;
      powerManagement.enable = cfg.powerManagement.enable;
      nvidiaSettings = true;
    };

    # Graphics and VA-API support
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        egl-wayland
        nvidia-vaapi-driver
      ];
    };

    services.xserver.videoDrivers = ["nvidia"];

    # Blacklist nouveau to prevent conflicts
    boot.blacklistedKernelModules = ["nouveau"];

    # Early KMS - load nvidia modules in initrd for earlier boot
    # This enables DRM kernel mode setting early in the boot process
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    # Environment variables for Wayland/Hyprland compatibility
    environment.sessionVariables = {
      # Ensure GLX uses the NVIDIA driver
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";

      # VA-API configuration for hardware video acceleration
      # See: https://github.com/elFarto/nvidia-vaapi-driver
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "direct";
    };

    # CUDA and license configuration
    nixpkgs.config = {
      nvidia.acceptLicense = true;
      cudaSupport = cfg.cuda.enable;
    };

    # ZFP is a floating-point compression library used by FreeCAD (transitively
    # through OpenCASCADE). When cudaSupport is enabled globally, zfp builds
    # with CUDA support, but CUDA has strict compiler version requirements.
    #
    # CUDA 12.x only supports GCC <= 14, but nixpkgs unstable uses GCC 15 as
    # the default stdenv. This causes zfp's CUDA compilation to fail with:
    #   "error: unsupported GNU version! gcc versions later than 14 are not supported!"
    #
    # The fix is to use cudaPackages.backendStdenv, which provides a GCC version
    # compatible with the CUDA toolkit.
    nixpkgs.overlays = mkIf cfg.cuda.enable [
      (final: prev: {
        zfp = prev.zfp.override {
          stdenv = final.cudaPackages.backendStdenv;
        };
      })
    ];
  };
}

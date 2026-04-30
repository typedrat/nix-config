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
    enable =
      mkEnableOption "NVIDIA GPU support with Hyprland/Wayland optimizations"
      // {
        default = let
          gpuCfg = config.rat.hardware.gpu;
          vendors =
            if builtins.isList gpuCfg.vendor
            then gpuCfg.vendor
            else [gpuCfg.vendor];
        in
          builtins.elem "nvidia" vendors;
      };

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

    package = mkOption {
      type = types.enum [
        "stable"
        "production"
        "beta"
        "vulkan_beta"
        "dc"
        "dc_570"
        "dc_580"
        "dc_590"
        "latest"
        "legacy_340"
        "legacy_390"
        "legacy_470"
        "legacy_535"
        "legacy_580"
      ];
      default = "stable";
      description = "NVIDIA driver package to use from linuxPackages.nvidiaPackages";
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
      package = config.boot.kernelPackages.nvidiaPackages.${cfg.package};
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

      # Point Vulkan loader directly at the NVIDIA ICD
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";

      # Qt WebEngine 6.10.2 incorrectly detects GBM as unsupported with NVIDIA
      # open kernel modules and falls back to a Vulkan rendering path that
      # deadlocks during Chromium initialization. Force-enabling GBM works
      # around this since the open modules do support GBM properly.
      # (NixOS/nixpkgs#508998)
      QTWEBENGINE_FORCE_USE_GBM = "1";
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

        # Mozilla mach (firefox/thunderbird) hardcodes onnxruntime as a build
        # input. With cudaSupport=true globally this drags cudnn/nccl/cufft into
        # the closure. firefox-unwrapped is built by cache.nixos-cuda.org so it
        # substitutes fine, but thunderbird-unwrapped is not on either cache,
        # forcing a multi-hour from-source rebuild on every nixpkgs bump.
        # Pin thunderbird's onnxruntime to the non-CUDA build to match Hydra's
        # cache.nixos.org hash for thunderbird-unwrapped.
        thunderbird-unwrapped = prev.thunderbird-unwrapped.override {
          onnxruntime = prev.onnxruntime.override { cudaSupport = false; };
        };
      })
    ];

    environment.systemPackages = with pkgs; [
      nvitop
    ];
  };
}

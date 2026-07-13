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
        "new_feature"
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
      description = ''
        NVIDIA driver package to use from linuxPackages.nvidiaPackages.

        "new_feature" tracks NVIDIA's New Feature branch (currently 610.x),
        distinct from "production"/"stable" (currently 595.x). "latest" picks
        whichever of production/new_feature has the higher version number,
        so it isn't a stable way to pin to the New Feature branch.
      '';
    };

    cuda.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable CUDA support in nixpkgs";
    };

    profiling.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable GPU profiling for non-admin users.

        Adds cudaPackages.nsight_compute (kernel-level) and nsight_systems
        (timeline) to the system PATH and sets the
        NVreg_RestrictProfilingToAdminUsers=0 modprobe option, letting
        profiling tools read the GPU's performance counters without root.
      '';
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

      # Point Vulkan loader directly at the NVIDIA ICD.
      # NOTE: NVIDIA's ICD is named nvidia_icd.json (no arch suffix). Mesa
      # drivers use *.x86_64.json, but the proprietary NVIDIA driver does not.
      # Pointing VK_DRIVER_FILES at a missing file causes the Vulkan loader to
      # find zero ICDs (it disables default search when this is set), which
      # breaks every Vulkan app — including Zed's blade renderer.
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";

      # Qt WebEngine incorrectly detects GBM as unsupported with NVIDIA open
      # kernel modules and falls back to a Vulkan rendering path that deadlocks
      # during Chromium initialization. Force-enabling GBM works around this
      # since the open modules do support GBM properly.
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
        #
        # Overriding onnxruntime's own `cudaSupport` flag is not enough: its
        # opencv/openvino inputs still resolve through the cudaSupport=true
        # package set (CUDA builds on the GCC 14 backend stdenv), so the hash
        # diverges from Hydra's and never substitutes. Re-import nixpkgs with
        # cudaSupport fully off to reproduce Hydra's cache.nixos.org hash.
        thunderbird-unwrapped = prev.thunderbird-unwrapped.override {
          inherit
            (import prev.path {
              inherit (prev.stdenv.hostPlatform) system;
              config = prev.config // {cudaSupport = false;};
            })
            onnxruntime
            ;
        };
      })
    ];

    # By default the driver restricts GPU performance counters to root; clearing
    # this lets Nsight Compute profile as a normal user.
    hardware.nvidia.moduleParams = mkIf cfg.profiling.enable {
      nvidia.NVreg_RestrictProfilingToAdminUsers = 0;
    };

    environment.systemPackages = with pkgs;
      [
        nvitop
      ]
      ++ lib.optionals cfg.profiling.enable [
        cudaPackages.nsight_compute
        cudaPackages.nsight_systems
      ];
  };
}

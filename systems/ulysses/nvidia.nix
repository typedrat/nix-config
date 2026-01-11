{pkgs, ...}: {
  nixpkgs.overlays = [
    (final: prev: {
      # ZFP is a floating-point compression library used by FreeCAD (transitively
      # through OpenCASCADE). When cudaSupport is enabled globally, zfp builds
      # with CUDA support, but CUDA has strict compiler version requirements.
      #
      # CUDA 12.x only supports GCC <= 14, but nixpkgs unstable uses GCC 15 as
      # the default stdenv. This causes zfp's CUDA compilation to fail with:
      #   "error: unsupported GNU version! gcc versions later than 14 are not supported!"
      #
      # The fix is to use cudaPackages.backendStdenv, which provides a GCC version
      # compatible with the CUDA toolkit. This stdenv is specifically maintained
      # for CUDA compilation and will automatically use the correct compiler.
      zfp = prev.zfp.override {
        stdenv = final.cudaPackages.backendStdenv;
      };
    })
  ];

  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];
    };

    nvidia = {
      open = true;
      nvidiaPersistenced = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
    };
  };

  services.xserver.videoDrivers = ["nvidia"];

  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.cudaSupport = true;

  boot.blacklistedKernelModules = ["nouveau"];
}

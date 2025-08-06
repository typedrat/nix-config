{pkgs, ...}: {
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];
    };

    nvidia = {
      open = false;
      nvidiaPersistenced = true;
      modesetting.enable = true;
      powerManagement.enable = false;
      nvidiaSettings = true;
    };
  };

  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.cudaSupport = true;

  boot.blacklistedKernelModules = ["nouveau"];
}

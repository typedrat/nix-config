{pkgs, ...}: {
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

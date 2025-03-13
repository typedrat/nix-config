{pkgs, ...}: {
  programs.virt-manager.enable = true;
  users.users.awilliams.extraGroups = ["libvirtd"];

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        ovmf.packages = [pkgs.OVMFFull.fd];
      };
    };
    spiceUSBRedirection.enable = true;
  };
}

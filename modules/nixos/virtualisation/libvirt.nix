{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib) modules options;
  cfg = config.rat.virtualisation.libvirt;
in {
  options.rat.virtualisation.libvirt = {
    enable = options.mkEnableOption "libvirt virtualization with NixVirt";
  };

  imports = [inputs.nixvirt.nixosModules.default];

  config = modules.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    virtualisation.libvirt.connections."qemu:///system" = {
      pools = [
        {
          definition = inputs.nixvirt.lib.pool.writeXML {
            name = "default";
            uuid = "650816fe-3d26-4e01-8ac0-09c2a0879831";
            type = "dir";
            target = {path = "/var/lib/libvirt/images";};
          };
          active = true;
        }
      ];
    };
  };
}

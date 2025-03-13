{
  inputs,
  lib,
  config,
  ...
}: let
  nixvirt = inputs.nixvirt;
  vm-path = "${config.home.homeDirectory}/VMs";
in {
  virtualisation.libvirt.enable = true;
  virtualisation.libvirt.verbose = true;
  virtualisation.libvirt.swtpm.enable = true;
  virtualisation.libvirt.connections."qemu:///session" = {
    domains = [
      {
        definition = nixvirt.lib.domain.writeXML (
          lib.attrsets.recursiveUpdate
          (nixvirt.lib.domain.templates.windows
            rec {
              name = "WindowsVM";
              uuid = "0f736971-4780-47cb-8389-d8d7f041dbf9";
              memory = {
                count = 8;
                unit = "GiB";
              };
              storage_vol = {
                pool = "vm-pool";
                volume = "WindowsVM.qcow2";
              };
              install_vol = "${vm-path}/Win11_24H2_English_x64.iso";
              nvram_path = "${vm-path}/${name}.nvram";
              virtio_net = true;
              virtio_drive = true;
              install_virtio = true;
            })
          {
            devices = {
              interface = {
                type = "user";
              };
            };
          }
        );
      }
    ];

    pools = [
      {
        definition = nixvirt.lib.pool.writeXML {
          name = "vm-pool";
          uuid = "3eec9923-1ae1-4455-8c05-0e9c1cb218c9";
          type = "dir";
          target = {path = "${vm-path}/vm-pool";};
        };
        active = true;
        volumes = [
          {
            definition = nixvirt.lib.volume.writeXML {
              name = "WindowsVM.qcow2";
              capacity = {
                count = 50;
                unit = "GB";
              };
              target = {
                format.type = "qcow2";
              };
            };
          }
        ];
      }
    ];
  };
}

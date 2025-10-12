{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.home-assistant;
in {
  options.rat.services.home-assistant = {
    enable = options.mkEnableOption "Home Assistant OS VM";

    memory = options.mkOption {
      type = types.int;
      default = 4;
      description = "RAM in GiB for Home Assistant VM";
    };

    diskPath = options.mkOption {
      type = types.str;
      default = "/var/lib/libvirt/images/homeassistant.qcow2";
      description = "Path to Home Assistant OS disk image";
    };
  };

  config = modules.mkIf cfg.enable {
    rat.virtualisation.libvirt.enable = true;

    virtualisation.libvirt.connections."qemu:///system" = {
      domains = [
        {
          definition = inputs.nixvirt.lib.domain.writeXML (
            inputs.nixvirt.lib.domain.templates.linux {
              name = "homeassistant";
              uuid = "a3d6c8e1-4b2f-4c9a-8e7d-1f5c3a9b2e4d";
              memory = {
                count = cfg.memory;
                unit = "GiB";
              };
              storage_vol = {
                pool = "default";
                volume = builtins.baseNameOf cfg.diskPath;
              };
              nvram = {
                template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
                path = "/var/lib/libvirt/qemu/nvram/homeassistant_VARS.fd";
              };
              virtio_net = true;
              virtio_drive = true;
            }
          );
          active = true;
        }
      ];
    };
  };
}

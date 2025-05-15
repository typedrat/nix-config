{
  self,
  self',
  inputs,
  inputs',
  ...
}: {
  rat.virtualisation.microvm.enable = true;

  microvm.vms.synapdeck-backend = {
    specialArgs = {
      inherit self self' inputs inputs';
    };

    config = {
      config,
      pkgs,
      ...
    }: {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        inputs.microvm.nixosModules.microvm

        ../../modules/nixos
        ../../users
      ];

      microvm = {
        hypervisor = "cloud-hypervisor";

        vcpu = 2;
        mem = 1024 * 2;
        hotplugMem = 1024 * 6;
        hotpluggedMem = 1024 * 2;

        shares = [
          {
            tag = "ro-store";
            proto = "virtiofs";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
          {
            tag = "persist";
            proto = "virtiofs";
            source = "/persist/vms/${config.networking.hostName}";
            mountPoint = "/persist";
          }
        ];

        devices = [
          {
            bus = "pci";
            path = "0000:65:00.1";
          }
        ];
      };
      fileSystems."/persist".neededForBoot = true;

      boot.kernelPackages = pkgs.linuxPackages_hardened;
      networking.hostName = "synapdeck-backend";

      rat = {
        boot.loader = "systemd-boot";

        impermanence = {
          enable = true;
          persistDir = "/persist";
        };

        nix-config.enable = false;

        security.sudo.sshAgentAuth.enable = true;
      };

      system.stateVersion = "25.05";
    };
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options strings types;
  cfg = config.rat.virtualisation.pciPassthrough;
in {
  options.rat.virtualisation.pciPassthrough = {
    enable = options.mkEnableOption "PCI Passthrough";

    cpuType = options.mkOption {
      description = "One of `intel` or `amd`";
      type = types.nullOr (types.enum ["intel" "amd"]);
    };

    pciIDs = options.mkOption {
      description = "List of PCI IDs to pass-through";
      type = types.listOf types.str;
      default = [];
    };
  };

  config = modules.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.cpuType != null;
        message = "CPU type must be set if rat.virtualisation.pciPassthrough is enabled!";
      }
    ];

    boot.kernelParams = [
      "${cfg.cpuType}_iommu=on"
      (modules.mkIf (cfg.cpuType == "intel") "iommu=pt")
    ];

    boot.kernelModules = ["vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd"];

    boot.extraModprobeConfig = ''
      options vfio-pci ids=${strings.concatStringsSep "," cfg.pciIDs}
      options vfio_iommu_type1 allow_unsafe_interrupts=1
    '';
  };
}

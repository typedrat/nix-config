{config, ...}: {
  # NCT6687D is a Nuvoton Super I/O chip used on many modern motherboards
  # (including ASUS and MSI boards) for hardware monitoring. This out-of-tree
  # kernel module exposes fan speeds, temperatures, and voltages to userspace
  # tools like lm_sensors and coolercontrol.
  boot.extraModulePackages = with config.boot.kernelPackages; [
    nct6687d
  ];

  boot.kernelModules = ["nct6687"];
}

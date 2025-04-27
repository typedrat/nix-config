{lib, ...}: let
  inherit (lib) options;
in {
  imports = [
    ./authentik.nix
    ./ipmi.nix
    ./nginx.nix
    ./node.nix
    ./postgres.nix
    ./zfs.nix
  ];

  options.rat.services.prometheus.exporters = {
    enable = options.mkEnableOption "Prometheus exporters" // {default = true;};
  };
}

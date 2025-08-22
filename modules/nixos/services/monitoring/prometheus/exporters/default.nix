{lib, ...}: let
  inherit (lib) options;
in {
  imports = [
    ./authentik.nix
    ./exportarr.nix
    ./hydra.nix
    ./ipmi.nix
    ./loki.nix
    ./node.nix
    ./postgres.nix
    ./traefik.nix
    ./qbittorrent.nix
    ./zfs.nix
  ];

  options.rat.services.prometheus.exporters = {
    enable = options.mkEnableOption "Prometheus exporters" // {default = true;};
  };
}

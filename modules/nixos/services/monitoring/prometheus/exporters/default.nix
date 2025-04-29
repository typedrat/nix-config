{lib, ...}: let
  inherit (lib) options;
in {
  imports = [
    ./authentik.nix
    ./exportarr.nix
    ./ipmi.nix
    ./loki.nix
    ./node.nix
    ./postgres.nix
    ./rtorrent.nix
    ./traefik.nix
    ./zfs.nix
  ];

  options.rat.services.prometheus.exporters = {
    enable = options.mkEnableOption "Prometheus exporters" // {default = true;};
  };
}

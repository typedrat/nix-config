{
  self,
  lib,
  ...
}: let
  inherit (lib) options types;
in {
  imports = [
    self.nixosModules.port-magic

    ./prometheus
    ./traefik
    ./acme.nix
    ./authentik.nix
    ./grafana.nix
    ./jellyfin.nix
    ./loki.nix
    ./monitor.nix
    ./mysql.nix
    ./postgres.nix
    ./shoko.nix
    ./torrents.nix
  ];

  options.rat.services.domainName = options.mkOption {
    type = types.str;
    default = "example.com";
    description = "The domain name for services exposed by this host.";
  };
}

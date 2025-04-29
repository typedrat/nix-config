{
  self,
  lib,
  ...
}: let
  inherit (lib) options types;
in {
  disabledModules = [
    "services/misc/servarr/lidarr.nix"
    "services/misc/servarr/radarr.nix"
    "services/misc/servarr/readarr.nix"
    "services/misc/servarr/sonarr.nix"
    "services/misc/servarr/whisparr.nix"
  ];

  imports = [
    self.nixosModules.port-magic
    self.nixosModules.servarr-multitenant

    ./core/traefik
    ./core/acme.nix
    ./core/authentik.nix
    ./core/monitor.nix
    ./core/mysql.nix
    ./core/postgres.nix

    ./media/jellyfin.nix
    ./media/prowlarr.nix
    ./media/radarr.nix
    ./media/radarr-anime.nix
    ./media/shoko.nix
    ./media/sonarr.nix
    ./media/sonarr-anime.nix
    ./media/torrents.nix

    ./monitoring/prometheus
    ./monitoring/grafana.nix
    ./monitoring/loki.nix
  ];

  options.rat.services.domainName = options.mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "The domain name for services exposed by this host.";
  };
}

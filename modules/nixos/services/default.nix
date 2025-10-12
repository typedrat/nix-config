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

    ./core
    ./communication
    ./development
    ./home-assistant.nix
    ./media
    ./monitoring
  ];

  options.rat.services.domainName = options.mkOption {
    type = types.str;
    default = "thisratis.gay";
    description = "The domain name for services exposed by this host.";
  };
}

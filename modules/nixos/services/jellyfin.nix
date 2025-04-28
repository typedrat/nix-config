{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellyfin;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.jellyfin = {
    enable = options.mkEnableOption "Jellyfin";
    subdomain = options.mkOption {
      type = types.str;
      default = "jellyfin";
      description = "The subdomain for Jellyfin.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        group = "media";
        openFirewall = true;
      };

      links.jellyfin = {
        protocol = "http";
        port = 8096;
      };

      rat.services.traefik.routes.jellyfin = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.jellyfin.url;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.jellyfin.dataDir;
            inherit (config.services.jellyfin) user group;
          }
        ];
      };
    })
  ];
}

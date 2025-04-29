{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;

  enabledServarr = {
    sonarr = config.rat.services.sonarr.enable;
    sonarr-anime = config.rat.services.sonarr.anime.enable;
    radarr = config.rat.services.radarr.enable;
    radarr-anime = config.rat.services.radarr.anime.enable;
    prowlarr = config.rat.services.prowlarr.enable;
  };

  getServarrConfig = name: let
    baseConfig = {
      sonarr = {
        type = "sonarr";
        apiKeyFile = config.sops.secrets."sonarr/apiKey".path;
        url = config.links.sonarr.url;
      };
      sonarr-anime = {
        type = "sonarr";
        apiKeyFile = config.sops.secrets."sonarr-anime/apiKey".path;
        url = config.links.sonarr-anime.url;
      };
      radarr = {
        type = "radarr";
        apiKeyFile = config.sops.secrets."radarr/apiKey".path;
        url = config.links.radarr.url;
      };
      radarr-anime = {
        type = "radarr";
        apiKeyFile = config.sops.secrets."radarr-anime/apiKey".path;
        url = config.links.radarr-anime.url;
      };
      prowlarr = {
        type = "prowlarr";
        apiKeyFile = config.sops.secrets."prowlarr/apiKey".path;
        url = config.links.prowlarr.url;
      };
    };
  in
    baseConfig.${name};

  exportarrConfigs = lib.filterAttrs (name: enabled: enabled) enabledServarr;
in {
  config = modules.mkIf cfg.enable {
    links =
      lib.mapAttrs
      (name: _: {
        protocol = "http";
      })
      (lib.mapAttrs' (name: _: lib.nameValuePair "exportarr-${name}" null) exportarrConfigs);

    services.exportarr = {
      instances =
        lib.mapAttrs
        (name: _: let
          serviceConfig = getServarrConfig name;
        in {
          enable = true;
          type = serviceConfig.type;
          url = serviceConfig.url;
          apiKeyFile = serviceConfig.apiKeyFile;
          port = config.links."exportarr-${name}".port;
          openFirewall = true;
          user = "${name}-exporter";
          group = "${name}-exporter";
        })
        exportarrConfigs;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "exportarr";
        static_configs =
          lib.mapAttrsToList
          (name: _: {
            targets = [config.links."exportarr-${name}".tuple];
            labels = {
              instance = name;
              app = (getServarrConfig name).type;
            };
          })
          exportarrConfigs;
      }
    ];
  };
}

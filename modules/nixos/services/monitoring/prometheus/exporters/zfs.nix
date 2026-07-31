{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;

  cfg = config.rat.services.prometheus;
  exportersCfg = cfg.exporters;

  link = config.links.prometheus-zfs;
in {
  config = modules.mkMerge [
    {
      links.prometheus-zfs = {
        protocol = "http";
      };
    }

    (modules.mkIf exportersCfg.enable {
      services.prometheus.exporters.zfs = {
        enable = true;
        inherit (link) port;
        listenAddress = link.ipv4;
      };
    })

    (modules.mkIf cfg.enable {
      services.prometheus.scrapeConfigs = [
        {
          job_name = "zfs";
          scrape_interval = cfg.hostScrapeInterval;
          static_configs = [
            {
              targets = [link.tuple];
              labels.instance = config.networking.hostName;
            }
          ];
        }
      ];
    })
  ];
}

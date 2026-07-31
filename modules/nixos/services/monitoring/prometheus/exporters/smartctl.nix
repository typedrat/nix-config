{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;

  cfg = config.rat.services.prometheus;
  exportersCfg = cfg.exporters;

  link = config.links.prometheus-smartctl;
in {
  config = modules.mkMerge [
    {
      links.prometheus-smartctl = {
        protocol = "http";
      };
    }

    (modules.mkIf exportersCfg.enable {
      services.prometheus.exporters.smartctl = {
        enable = true;
        inherit (link) port;
        listenAddress = link.ipv4;
      };
    })

    (modules.mkIf cfg.enable {
      # No scrape_interval override: the exporter only re-reads SMART data once
      # a minute, so polling it faster than the global default just re-serves
      # the same numbers.
      services.prometheus.scrapeConfigs = [
        {
          job_name = "smartctl";
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

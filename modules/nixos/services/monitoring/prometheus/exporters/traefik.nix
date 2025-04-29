{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.traefik.enable) {
    # Configure Prometheus to scrape Traefik's metrics endpoint
    services.prometheus.scrapeConfigs = [
      {
        job_name = "traefik";
        static_configs = [
          {
            targets = [config.links.traefik-metrics.tuple];
          }
        ];
      }
    ];
  };
}

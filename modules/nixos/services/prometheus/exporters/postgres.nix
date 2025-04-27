{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.postgres.enable) {
    services.prometheus.exporters.postgres = {
      enable = true;
      inherit (config.links.prometheus-postgres) port;
    };

    links.prometheus-postgres = {
      protocol = "http";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = [config.links.prometheus-postgres.tuple];
          }
        ];
      }
    ];
  };
}

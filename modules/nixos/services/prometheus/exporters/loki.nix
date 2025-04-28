{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.loki.enable) {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "loki";
        static_configs = [
          {
            targets = [config.links.loki.tuple];
          }
        ];
      }
    ];
  };
}

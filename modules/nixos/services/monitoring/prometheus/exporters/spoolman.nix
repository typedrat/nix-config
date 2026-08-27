{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.spoolman.enable) {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "spoolman";
        static_configs = [
          {
            targets = [config.links.spoolman.tuple];
          }
        ];
      }
    ];
  };
}

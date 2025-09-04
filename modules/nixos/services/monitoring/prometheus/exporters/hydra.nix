{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.hydra.enable) {
    services.prometheus.scrapeConfigs = [
      {
        job_name = "hydra-notify";
        static_configs = [
          {
            targets = [config.links.prometheus-hydra-notify.tuple];
            labels = {
              instance = "hydra-notify";
            };
          }
        ];
      }
      {
        job_name = "hydra-queue-runner";
        static_configs = [
          {
            targets = [config.links.prometheus-hydra-queue-runner.tuple];
            labels = {
              instance = "hydra-queue-runner";
            };
          }
        ];
      }
    ];
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      inherit (config.links.prometheus-node) port;
      enabledCollectors = ["systemd"];
    };

    links.prometheus-node = {
      protocol = "http";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [config.links.prometheus-node.tuple];
          }
        ];
      }
    ];
  };
}

{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.nginx.enable) {
    services.prometheus.exporters.nginx = {
      enable = true;
      inherit (config.links.prometheus-nginx) port;
    };

    links.prometheus-nginx = {
      protocol = "http";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "nginx";
        static_configs = [
          {
            targets = [config.links.prometheus-nginx.tuple];
          }
        ];
      }
    ];
  };
}

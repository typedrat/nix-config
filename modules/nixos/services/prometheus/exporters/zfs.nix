{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf cfg.enable {
    services.prometheus.exporters.zfs = {
      enable = true;
      inherit (config.links.prometheus-zfs) port;
    };

    links.prometheus-zfs = {
      protocol = "http";
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [config.links.prometheus-zfs.tuple];
          }
        ];
      }
    ];
  };
}

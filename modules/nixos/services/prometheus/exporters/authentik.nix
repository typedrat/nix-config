{
  config,
  lib,
  ...
}: let
  inherit (lib) modules;
  cfg = config.rat.services.prometheus.exporters;
in {
  config = modules.mkIf (cfg.enable && config.rat.services.authentik.enable) {
    services.prometheus.scrapeConfigs = [
      (lib.mkIf config.services.authentik.enable {
        job_name = "authentik";
        static_configs = [
          {
            targets = [config.links.prometheus-authentik.tuple];
          }
        ];
      })
      (lib.mkIf config.services.authentik-ldap.enable {
        job_name = "authentik-ldap";
        static_configs = [
          {
            targets = [config.links.prometheus-authentik-ldap.tuple];
          }
        ];
      })
    ];
  };
}

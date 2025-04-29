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
      {
        job_name = "authentik";
        static_configs = [
          {
            targets = [config.links.prometheus-authentik.tuple];
            labels = {
              instance = "authentik";
            };
          }
          (
            lib.mkIf config.services.authentik-ldap.enable
            {
              targets = [config.links.prometheus-authentik-ldap.tuple];
              labels = {
                instance = "authentik-ldap";
              };
            }
          )
        ];
      }
    ];
  };
}

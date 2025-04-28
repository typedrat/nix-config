{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.grafana;
  impermanenceCfg = config.rat.impermanence;
  inherit (config.rat.services) domainName;
in {
  options.rat.services.grafana = {
    enable = options.mkEnableOption "Grafana";
    subdomain = options.mkOption {
      type = types.str;
      default = "grafana";
      description = "The subdomain for Grafana.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            inherit (config.links.grafana) port;
            enforce_domain = true;
            enable_gzip = true;
            domain = "${cfg.subdomain}.${domainName}";
            root_url = "https://${cfg.subdomain}.${domainName}";
          };
        };
      };

      links = {
        grafana = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.grafana = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.grafana.url;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = config.services.grafana.dataDir;
            user = "grafana";
            group = "grafana";
          }
        ];
      };
    })
  ];
}

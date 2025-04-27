{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.prometheus;
  impermanenceCfg = config.rat.impermanence;

  persistentGroup = "prometheus-persist";
  persistentStatePath = "${impermanenceCfg.persistDir}/var/lib/${config.services.prometheus.stateDir}";
in {
  imports = [
    ./exporters
  ];

  options.rat.services.prometheus = {
    enable = options.mkEnableOption "Prometheus";

    subdomain = options.mkOption {
      type = types.str;
      default = "prometheus";
      description = "The subdomain for Prometheus.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.prometheus = {
        enable = true;
        enableReload = true;
        inherit (config.links.prometheus) port;
      };

      links.prometheus = {
        protocol = "http";
      };

      rat.services.nginx.virtualHosts."${cfg.subdomain}" = {
        authentik.enable = true;

        locations."/" = {
          proxyPass = config.links.prometheus.url;
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      users.groups.${persistentGroup} = {};

      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = persistentStatePath;
          user = "root";
          group = persistentGroup;
          mode = "0770";
        }
      ];

      systemd.services.prometheus = {
        serviceConfig = {
          # Add the dynamic user to our static supplementary group
          SupplementaryGroups = [persistentGroup];

          # Bind mount the actual persistent storage location into the service's namespace
          BindPaths = ["${persistentStatePath}:/var/lib/${config.services.prometheus.stateDir}"];

          # Ensure the persistent directory exists before systemd tries to bind mount it.
          ExecStartPre = "+${pkgs.coreutils}/bin/mkdir -p ${persistentStatePath}";
        };
      };
    })
  ];
}

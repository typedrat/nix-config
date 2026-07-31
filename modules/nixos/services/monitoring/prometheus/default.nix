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
    ./push.nix
  ];

  options.rat.services.prometheus = {
    enable = options.mkEnableOption "Prometheus";

    subdomain = options.mkOption {
      type = types.str;
      default = "prometheus";
      description = "The subdomain for Prometheus.";
    };

    hostScrapeInterval = options.mkOption {
      type = types.str;
      default = "15s";
      description = ''
        Scrape interval for this host's own node and ZFS jobs. Prometheus
        defaults to a minute, which is too coarse to see what a machine was
        doing in the moments before it stopped answering.
      '';
    };

    remoteWrite = {
      enable = options.mkEnableOption ''
        the remote-write receiver, letting other machines push metrics here
        instead of being scraped
      '';

      allowFrom = options.mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["10.0.0.0/24"];
        description = "Source ranges permitted to push metrics to this host.";
      };
    };
  };

  config = modules.mkMerge [
    {
      # Declared unconditionally: hosts that push metrics here need the port
      # without running Prometheus themselves.
      links.prometheus = {
        protocol = "http";
      };
    }

    (modules.mkIf cfg.enable {
      services.prometheus = {
        enable = true;
        enableReload = true;
        inherit (config.links.prometheus) port;
      };

      rat.services.traefik.routes.prometheus = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.prometheus.url;
        authentik = true;
      };
    })
    (modules.mkIf (cfg.enable && cfg.remoteWrite.enable) {
      services.prometheus.extraFlags = ["--web.enable-remote-write-receiver"];

      rat.networking.scopedPorts = modules.mkIf (cfg.remoteWrite.allowFrom != []) [
        {
          ports = [config.links.prometheus.port];
          sources = cfg.remoteWrite.allowFrom;
        }
      ];
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

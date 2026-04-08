{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.qui;
  impermanenceCfg = config.rat.impermanence;
in {
  options.rat.services.qui = {
    enable = options.mkEnableOption "qui";
    subdomain = options.mkOption {
      type = types.str;
      default = "qui";
      description = "The subdomain for qui.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.rat.services.torrents.enable;
          message = "qui requires torrents to be enabled";
        }
      ];

      services.qui = {
        enable = true;
        group = "media";

        secretFile = config.sops.secrets."qui/sessionSecret".path;

        settings = {
          host = config.links.qui.ipv4;
          inherit (config.links.qui) port;

          qbitUrl = config.links.qbittorrent-webui.url;
        };
      };

      sops.secrets."qui/sessionSecret" = {
        sopsFile = ../../../../secrets/qui.yaml;
        key = "sessionSecret";
        owner = config.services.qui.user;
        inherit (config.services.qui) group;
      };

      links.qui = {
        protocol = "http";
      };

      rat.services.traefik.routes.qui = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.qui.url;

        authentik = true;
      };

      systemd.services.qui = {
        after = ["qbittorrent.service"];
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/qui";
            inherit (config.services.qui) user group;
          }
        ];
      };
    })
  ];
}

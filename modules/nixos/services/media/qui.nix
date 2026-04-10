{
  config,
  lib,
  ...
}:
let
  inherit (lib) modules options types;
  cfg = config.rat.services.qui;
  impermanenceCfg = config.rat.impermanence;
  authentikCfg = config.rat.services.authentik;

  inherit (config.rat.services) domainName;
in
{
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

      sops.secrets."qui/oidcClientSecret" = {
        sopsFile = ../../../../secrets/qui.yaml;
        key = "oidcClientSecret";
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
      };

      systemd.services.qui = {
        after = [ "qbittorrent.service" ];

        serviceConfig = {
          LoadCredential = [
            "oidcClientSecret:${config.sops.secrets."qui/oidcClientSecret".path}"
          ];
          Environment = [
            "QUI__OIDC_ENABLED=true"
            "QUI__OIDC_ISSUER=https://${authentikCfg.subdomain}.${domainName}/application/o/qui/"
            "QUI__OIDC_CLIENT_ID=qui"
            "QUI__OIDC_CLIENT_SECRET_FILE=%d/oidcClientSecret"
            "QUI__OIDC_REDIRECT_URL=https://${cfg.subdomain}.${domainName}/api/auth/oidc/callback"
            "QUI__OIDC_DISABLE_BUILT_IN_LOGIN=true"
          ];
        };
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

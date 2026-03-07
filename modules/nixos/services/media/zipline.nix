{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.zipline;
  impermanenceCfg = config.rat.impermanence;
  authentikCfg = config.rat.services.authentik;

  inherit (config.rat.services) domainName;

  domain = "${cfg.subdomain}.${domainName}";
in {
  options.rat.services.zipline = {
    enable = options.mkEnableOption "Zipline";
    subdomain = options.mkOption {
      type = types.str;
      default = "zipline";
      description = "The subdomain for Zipline.";
    };
    uploadsDir = options.mkOption {
      type = types.str;
      default = "/var/lib/zipline/uploads";
      description = "Directory for uploaded files.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      links.zipline = {
        protocol = "http";
      };

      services.zipline = {
        enable = true;
        database.createLocally = false;

        settings = {
          CORE_HOSTNAME = config.links.zipline.ipv4;
          CORE_PORT = config.links.zipline.port;
          CORE_TRUST_PROXY = "true";
          CORE_RETURN_HTTPS_URLS = "true";
          CORE_DEFAULT_DOMAIN = domain;

          DATASOURCE_TYPE = "local";
          DATASOURCE_LOCAL_DIRECTORY = cfg.uploadsDir;

          FEATURES_OAUTH_REGISTRATION = "true";
          OAUTH_OIDC_AUTHORIZE_URL = "https://${authentikCfg.subdomain}.${domainName}/application/o/authorize/";
          OAUTH_OIDC_USERINFO_URL = "https://${authentikCfg.subdomain}.${domainName}/application/o/userinfo/";
          OAUTH_OIDC_TOKEN_URL = "https://${authentikCfg.subdomain}.${domainName}/application/o/token/";
          OAUTH_OIDC_REDIRECT_URI = "https://${domain}/api/auth/oauth/oidc";
        };

        environmentFiles = [
          config.sops.templates."zipline.env".path
        ];
      };

      sops.secrets."zipline/coreSecret" = {
        sopsFile = ../../../../secrets/zipline.yaml;
        key = "coreSecret";
        restartUnits = ["zipline.service"];
      };

      sops.secrets."zipline/clientId" = {
        sopsFile = ../../../../secrets/zipline.yaml;
        key = "clientId";
        restartUnits = ["zipline.service"];
      };

      sops.secrets."zipline/clientSecret" = {
        sopsFile = ../../../../secrets/zipline.yaml;
        key = "clientSecret";
        restartUnits = ["zipline.service"];
      };

      sops.secrets."zipline/db/password" = {
        sopsFile = ../../../../secrets/zipline.yaml;
        key = "db/password";
        owner = "postgres";
        group = "postgres";
        restartUnits = ["zipline.service"];
      };

      sops.templates."zipline.env" = {
        content = ''
          CORE_SECRET=${config.sops.placeholder."zipline/coreSecret"}
          DATABASE_URL=postgresql://zipline:${config.sops.placeholder."zipline/db/password"}@localhost:${toString config.links.postgres.port}/zipline
          OAUTH_OIDC_CLIENT_ID=${config.sops.placeholder."zipline/clientId"}
          OAUTH_OIDC_CLIENT_SECRET=${config.sops.placeholder."zipline/clientSecret"}
        '';
        restartUnits = ["zipline.service"];
      };

      rat.services.postgres = {
        enable = true;
        users.zipline = {
          passwordFile = config.sops.secrets."zipline/db/password".path;
          ownedDatabases = ["zipline"];
        };
      };

      systemd.services.zipline = {
        after = ["postgresql.service"];
        requires = ["postgresql.service"];
        serviceConfig.DynamicUser = lib.mkForce false;
      };

      users.users.zipline = {
        isSystemUser = true;
        group = "zipline";
        home = "/var/lib/zipline";
      };
      users.groups.zipline = {};

      rat.services.traefik.routes.zipline = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.zipline.url;
        authentik = false;
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir}.directories = [
        {
          directory = "/var/lib/zipline";
          user = "zipline";
          group = "zipline";
          mode = "0755";
        }
      ];
    })
  ];
}

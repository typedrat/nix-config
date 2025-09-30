{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib) modules options types;

  cfg = config.rat.services.authentik;
  inherit (config.rat.services) domainName;
  certDir = config.security.acme.certs."${domainName}-rsa4096".directory;

  mkAuthentikSecrets = secrets:
    builtins.listToAttrs (builtins.map (secret: {
        name = "authentik/${secret}";
        value = {
          sopsFile = ../../../../secrets/authentik.yaml;
          key = secret;
        };
      })
      secrets);
in {
  imports = [
    inputs.authentik-nix.nixosModules.default
  ];

  options.rat.services.authentik = {
    enable = options.mkEnableOption "Authentik";
    subdomain = options.mkOption {
      type = types.str;
      default = "auth";
      description = "The subdomain for authentik services exposed by this host.";
    };

    ldap.enable = options.mkEnableOption "Authentik's LDAP outpost";
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      services.authentik = {
        enable = true;
        environmentFile = config.sops.templates."authentik.env".path;
        settings = {
          disable_startup_analytics = true;
          avatars = "initials";
          redis = {
            inherit (config.links.authentik-redis) port;
          };
          cert_discovery_dir = certDir;
        };
      };

      systemd.services.authentik-worker.serviceConfig.LoadCredential = [
        "${certDir}/fullchain.pem"
        "${certDir}/key.pem"
      ];

      links = {
        authentik = {
          protocol = "http";
        };

        authentik-https = {
          protocol = "https";
        };

        prometheus-authentik = {
          protocol = "http";
        };

        authentik-redis = {
          protocol = "redis";
        };
      };

      services.redis.servers.authentik = {
        port = lib.mkForce config.links.authentik-redis.port;
      };

      rat.services.traefik.routes.authentik = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.authentik.url;
      };

      sops.secrets = mkAuthentikSecrets [
        "secret"
        "bootstrap/email"
        "bootstrap/password"
        "bootstrap/token"
      ];

      sops.templates."authentik.env" = {
        content = lib.toShellVars {
          AUTHENTIK_SECRET_KEY = config.sops.placeholder."authentik/secret";
          AUTHENTIK_BOOTSTRAP_EMAIL = config.sops.placeholder."authentik/bootstrap/email";
          AUTHENTIK_BOOTSTRAP_PASSWORD = config.sops.placeholder."authentik/bootstrap/password";
          AUTHENTIK_BOOTSTRAP_TOKEN = config.sops.placeholder."authentik/bootstrap/token";
          AUTHENTIK_LISTEN__HTTP = lib.mkForce config.links.authentik.tuple;
          AUTHENTIK_LISTEN__HTTPS = lib.mkForce config.links.authentik-https.tuple;
          AUTHENTIK_LISTEN__METRICS = lib.mkForce config.links.prometheus-authentik.tuple;
        };

        restartUnits = [
          "authentik.service"
          "authentik-worker.service"
        ];
      };
    })
    (modules.mkIf cfg.ldap.enable {
      services.authentik-ldap = {
        enable = true;
        environmentFile = config.sops.templates."authentik-ldap.env".path;
      };

      links = {
        authentik-ldap = {
          protocol = "ldap";
          port = 3389;
        };

        authentik-ldaps = {
          protocol = "ldaps";
          port = 6636;
        };

        prometheus-authentik-ldap = {
          protocol = "http";
        };
      };

      systemd.services.authentik-ldap.environment = {
        AUTHENTIK_LISTEN__METRICS = lib.mkForce (builtins.toString config.links.prometheus-authentik-ldap.tuple);
      };

      sops.secrets = mkAuthentikSecrets [
        "ldap/token"
      ];

      sops.templates."authentik-ldap.env" = {
        content = lib.toShellVars {
          AUTHENTIK_HOST = "https://${cfg.subdomain}.${domainName}";
          AUTHENTIK_INSECURE = "false";
          AUTHENTIK_TOKEN = config.sops.placeholder."authentik/ldap/token";
          AUTHENTIK_LISTEN__LDAP = lib.mkForce config.links.authentik-ldap.tuple;
          AUTHENTIK_LISTEN__LDAPS = lib.mkForce config.links.authentik-ldaps.tuple;
          AUTHENTIK_LISTEN__METRICS = lib.mkForce config.links.prometheus-authentik-ldap.tuple;
        };

        restartUnits = ["authentik-ldap.service"];
      };
    })
  ];
}

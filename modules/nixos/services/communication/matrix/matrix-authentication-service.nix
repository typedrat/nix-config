{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  inherit (config.rat.services) domainName;
  cfg = config.rat.services.matrix-authentication-service;

  synapseMscClientId = "0000000000000000000SYNAPSE";
in {
  options.rat.services.matrix-authentication-service = {
    subdomain = options.mkOption {
      type = types.str;
      default = "matrix-auth";
      description = "The subdomain to use for Matrix Authentication Service";
    };

    package = options.mkPackageOption pkgs "matrix-authentication-service" {};
  };

  config = modules.mkIf config.rat.services.matrix-synapse.enable {
    assertions = [
      {
        assertion = config.rat.services.authentik.enable;
        message = "Authentik must be enabled to use Matrix Authentication Service";
      }
    ];

    links = {
      matrix-auth = {
        protocol = "http";
      };
    };

    rat.services.traefik = {
      routes = {
        matrix-auth = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.matrix-auth.url;
        };

        matrix-auth-compat = {
          enable = true;
          inherit (config.rat.services.matrix-synapse) subdomain;
          serviceUrl = config.links.matrix-auth.url;
          pathRegex = "^/_matrix/client/(?:.*)/(login|logout|refresh)$";
          priority = 300; # Higher than the standard Matrix API routes
        };
      };
    };

    sops.secrets = {
      "matrix-auth/authentik/providerId" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "authentik/providerId";
      };
      "matrix-auth/authentik/clientId" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "authentik/clientId";
      };
      "matrix-auth/authentik/clientSecret" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "authentik/clientSecret";
      };
      "matrix-auth/authentik/issuerUrl" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "authentik/issuerUrl";
      };

      "matrix-auth/synapse/clientSecret" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "synapse/clientSecret";
      };
      "matrix-auth/synapse/adminToken" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "synapse/adminToken";
      };

      "matrix-auth/secrets.yaml" = {
        sopsFile = ../../../../../secrets/matrix.yaml;
        key = "secrets.yaml";
        owner = "matrix-authentication-service";
        group = "matrix-authentication-service";
      };
    };

    sops.templates."matrix-auth/synapse-msc3861.yaml" = {
      content = builtins.toJSON {
        experimental_features.msc3861 = {
          enabled = true;
          issuer = "https://${cfg.subdomain}.${domainName}/";
          client_id = synapseMscClientId;
          client_auth_method = "client_secret_basic";
          client_secret = config.sops.placeholder."matrix-auth/synapse/clientSecret";
          admin_token = config.sops.placeholder."matrix-auth/synapse/adminToken";
          account_management_url = "https://${cfg.subdomain}.${domainName}/account/";
        };
      };
      owner = "matrix-synapse";
      group = "matrix-synapse";
      mode = "0640";
      restartUnits = ["matrix-synapse.service"];
    };

    sops.templates."matrix-auth/synapse-client.json" = {
      content = builtins.toJSON {
        clients = [
          {
            client_id = synapseMscClientId;
            name = "Matrix Synapse";
            client_auth_method = "client_secret_basic";
            client_secret = config.sops.placeholder."matrix-auth/synapse/clientSecret";
          }
        ];

        matrix = {
          homeserver = config.services.matrix-synapse.settings.server_name;
          secret = config.sops.placeholder."matrix-auth/synapse/adminToken";
          endpoint = config.links.matrix-synapse.url;
        };
      };

      owner = "matrix-authentication-service";
      group = "matrix-authentication-service";
      mode = "0640";
      restartUnits = ["matrix-authentication-service.service"];
    };

    sops.templates."matrix-auth/authentik-config.json" = {
      content = builtins.toJSON {
        upstream_oauth2 = {
          providers = [
            {
              id = config.sops.placeholder."matrix-auth/authentik/providerId";
              human_name = "Authentik";
              issuer = config.sops.placeholder."matrix-auth/authentik/issuerUrl";
              client_id = config.sops.placeholder."matrix-auth/authentik/clientId";
              client_secret = config.sops.placeholder."matrix-auth/authentik/clientSecret";
              token_endpoint_auth_method = "client_secret_basic";
              scope = "openid profile email";
              claims_imports = {
                localpart = {
                  action = "require";
                  template = "{{ user.preferred_username }}";
                };
                displayname = {
                  action = "suggest";
                  template = "{{ user.name }}";
                };
                email = {
                  action = "require";
                  template = "{{ user.email }}";
                  set_email_verification = "always";
                };
              };
            }
          ];
        };
      };

      owner = "matrix-authentication-service";
      group = "matrix-authentication-service";
      mode = "0640";
      restartUnits = ["matrix-authentication-service.service"];
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = ["matrix-authentication-service"];
      ensureUsers = [
        {
          name = "matrix-authentication-service";
          ensureDBOwnership = true;
        }
      ];
    };

    services.matrix-synapse.extraConfigFiles = [config.sops.templates."matrix-auth/synapse-msc3861.yaml".path];

    users.users.matrix-authentication-service = {
      group = "matrix-authentication-service";
      isSystemUser = true;
    };
    users.groups.matrix-authentication-service = {};

    systemd.services.matrix-authentication-service = let
      settings = {
        http = {
          public_base = "https://${cfg.subdomain}.${domainName}/";
          issuer = "https://${cfg.subdomain}.${domainName}/";
          trusted_proxies = ["127.0.0.1/8" "::1/128"];

          listeners = [
            {
              name = "web";
              resources = [
                {name = "discovery";}
                {name = "human";}
                {name = "oauth";}
                {name = "compat";}
                {name = "graphql";}
                {
                  name = "assets";
                  path = "${cfg.package}/share/matrix-authentication-service/assets";
                }
              ];
              binds = [
                {
                  host = config.links.matrix-auth.ipv4;
                  inherit (config.links.matrix-auth) port;
                }
              ];
              proxy_protocol = false;
            }
            {
              name = "internal";
              resources = [
                {name = "health";}
              ];
              binds = [
                {
                  host = "127.0.0.1";
                  port = 8081;
                }
              ];
              proxy_protocol = false;
            }
          ];
        };

        database = {
          uri = "postgresql:///matrix-authentication-service?host=/run/postgresql";
          max_connections = 10;
          min_connections = 0;
          connect_timeout = 30;
          idle_timeout = 600;
          max_lifetime = 1800;
        };

        passwords.enabled = false;
      };

      finalSettings = lib.filterAttrsRecursive (_: v: v != null) settings;
      configFile = (pkgs.formats.yaml {}).generate "config.yaml" finalSettings;
    in {
      after = ["postgresql.service" "matrix-synapse.service" "authentik.service"];
      wants = ["postgresql.service" "matrix-synapse.service" "authentik.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        User = "matrix-authentication-service";
        Group = "matrix-authentication-service";
        StateDirectory = "matrix-authentication-service";

        ExecStartPre = [
          (pkgs.writeShellScript "matrix-authentication-service-check-config" ''
            ${lib.getExe cfg.package} config check \
              ${lib.concatMapStringsSep " " (x: "--config ${x}") [
              configFile
              config.sops.templates."matrix-auth/synapse-client.json".path
              config.sops.templates."matrix-auth/authentik-config.json".path
              config.sops.secrets."matrix-auth/secrets.yaml".path
            ]}
          '')
          (pkgs.writeShellScript "matrix-authentication-service-sync-config" ''
            ${lib.getExe cfg.package} config sync \
              ${lib.concatMapStringsSep " " (x: "--config ${x}") [
              configFile
              config.sops.templates."matrix-auth/synapse-client.json".path
              config.sops.templates."matrix-auth/authentik-config.json".path
              config.sops.secrets."matrix-auth/secrets.yaml".path
            ]}
          '')
        ];

        ExecStart = ''
          ${lib.getExe cfg.package} server \
            ${lib.concatMapStringsSep " " (x: "--config ${x}") [
            configFile
            config.sops.templates."matrix-auth/synapse-client.json".path
            config.sops.templates."matrix-auth/authentik-config.json".path
            config.sops.secrets."matrix-auth/secrets.yaml".path
          ]}
        '';

        Restart = "on-failure";
        RestartSec = "1s";
      };
    };
  };
}

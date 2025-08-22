{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.hydra;
  impermanenceCfg = config.rat.impermanence;
in {
  # ============================================================================
  # OPTIONS
  # ============================================================================

  options.rat.services.hydra = {
    enable = options.mkEnableOption "hydra";
    subdomain = options.mkOption {
      type = types.str;
      default = "hydra";
      description = "The subdomain for hydra.";
    };
    adminUser = options.mkOption {
      type = types.str;
      default = "admin";
      description = "The admin user for hydra.";
    };
    adminEmail = options.mkOption {
      type = types.str;
      description = "The admin email for hydra.";
    };
    bucket = options.mkOption {
      type = types.str;
      description = "The Backblaze B2 bucket name for binary cache storage.";
    };
    region = options.mkOption {
      type = types.str;
      default = "us-west-002";
      description = "The Backblaze B2 region.";
    };
  };

  # ============================================================================
  # CONFIGURATION
  # ============================================================================

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # --------------------------------------------------------------------------
      # Core Services
      # --------------------------------------------------------------------------

      # Enable Authentik LDAP outpost when Hydra is enabled
      rat.services.authentik.ldap.enable = true;

      services.hydra = {
        enable = true;
        port = config.links.hydra.port;
        hydraURL = "https://${cfg.subdomain}.${config.rat.services.traefik.domain}";
        notificationSender = cfg.adminEmail;
        buildMachinesFiles = [];
        useSubstitutes = true;

        # Database configuration using Unix socket
        dbi = "dbi:Pg:dbname=hydra;host=/run/postgresql;user=hydra;";

        # Notification configuration
        tracker = cfg.adminEmail;

        # LDAP Authentication with Authentik
        extraConfig = ''
          Include ${config.sops.templates."hydra-ldap.conf".path}
          Include ${config.sops.templates."hydra-github-webhook.conf".path}

          # Binary cache configuration (Backblaze B2)
          store_uri = s3://${cfg.bucket}?compression=zstd&parallel-compression=true&write-nar-listing=1&ls-compression=br&log-compression=br&secret-key=${config.sops.secrets."hydra/cachePrivateKey".path}&region=${cfg.region}&endpoint=https://s3.${cfg.region}.backblazeb2.com

          # Prometheus metrics configuration
          <hydra_notify>
            <prometheus>
              listen_address = ${config.links.prometheus-hydra-notify.hostname}
              port = ${toString config.links.prometheus-hydra-notify.port}
            </prometheus>
          </hydra_notify>

          queue_runner_metrics_address = ${config.links.prometheus-hydra-queue-runner.tuple}

          <ldap>
            <config>
              <credential>
                class = Password
                password_field = password
                password_type = self_check
              </credential>
              <store>
                class = LDAP
                ldap_server = ${config.links.authentik-ldap.tuple}
                ldap_server_options.timeout = 30
                binddn = "cn=ldap-search,ou=users,dc=ldap,dc=goauthentik,dc=io"
                start_tls = 0
                user_basedn = "ou=hydra,dc=ldap,dc=goauthentik,dc=io"
                user_filter = "(&(objectClass=inetOrgPerson)(cn=%s))"
                user_scope = one
                user_field = cn
                user_search_options.deref = always
                use_roles = 1
                role_basedn = "ou=hydra,dc=ldap,dc=goauthentik,dc=io"
                role_filter = "(&(objectClass=groupOfNames)(member=%s))"
                role_scope = one
                role_field = cn
                role_value = dn
                role_search_options.deref = always
              </store>
            </config>
            <role_mapping>
              "Hydra Administrator" = admin
              "Hydra Create Projects" = create-projects
              "Hydra Restart Jobs" = restart-jobs
              "Hydra Cancel Build" = cancel-build
            </role_mapping>
          </ldap>
        '';
      };

      # --------------------------------------------------------------------------
      # Database Configuration
      # --------------------------------------------------------------------------

      services.postgresql = {
        enable = true;
        ensureDatabases = ["hydra"];
        ensureUsers = [
          {
            name = "hydra";
            ensureDBOwnership = true;
          }
        ];
      };

      # --------------------------------------------------------------------------
      # SOPS Secrets Management
      # --------------------------------------------------------------------------

      # SOPS secret for LDAP bind password (reuse Authentik LDAP password)
      sops.secrets."authentik/ldap/password" = {
        sopsFile = ../../../../secrets/authentik.yaml;
        key = "ldap.password";
        owner = "hydra";
        group = "hydra";
        mode = "0600";
      };

      # SOPS secret for cache private key
      sops.secrets."hydra/cachePrivateKey" = {
        sopsFile = ../../../../secrets/hydra.yaml;
        key = "cacheKey.private";
        owner = "hydra";
        group = "hydra";
        mode = "0600";
        path = "/var/lib/hydra/cache-priv-key.pem";
      };

      # SOPS secret for GitHub webhook secret
      sops.secrets."hydra/githubWebhookSecret" = {
        sopsFile = ../../../../secrets/hydra.yaml;
        key = "webhookSecret.github";
        owner = "hydra";
        group = "hydra";
        mode = "0600";
      };

      # SOPS secrets for B2
      sops.secrets."hydra/b2/keyId" = {
        sopsFile = ../../../../secrets/default.yaml;
        key = "b2/keyId";
        owner = "hydra-queue-runner";
        group = "hydra";
        mode = "0600";
      };

      sops.secrets."hydra/b2/applicationKey" = {
        sopsFile = ../../../../secrets/default.yaml;
        key = "b2/applicationKey";
        owner = "hydra-queue-runner";
        group = "hydra";
        mode = "0600";
      };

      # --------------------------------------------------------------------------
      # SOPS Templates
      # --------------------------------------------------------------------------

      # SOPS template for LDAP configuration
      sops.templates."hydra-ldap.conf" = {
        content = ''
          <ldap>
            <config>
              <store>
                bindpw = ${config.sops.placeholder."authentik/ldap/password"}
              </store>
            </config>
          </ldap>
        '';
        owner = "hydra";
        group = "hydra";
        mode = "0660";
      };

      sops.templates."hydra-github-webhook.conf" = {
        content = ''
          # GitHub webhook secret
          <webhooks>
            <github>
              secret = ${config.sops.placeholder."hydra/githubWebhookSecret"}
            </github>
          </webhooks>
        '';
        owner = "hydra";
        group = "hydra";
        mode = "0660";
      };

      # AWS credentials file for B2
      sops.templates."hydra-aws-credentials" = {
        path = "/var/lib/hydra/queue-runner/.aws/credentials";
        content = ''
          [default]
          aws_access_key_id = ${config.sops.placeholder."hydra/b2/keyId"}
          aws_secret_access_key = ${config.sops.placeholder."hydra/b2/applicationKey"}
        '';
        owner = "hydra-queue-runner";
        group = "hydra";
        mode = "0600";
      };

      # --------------------------------------------------------------------------
      # System Configuration
      # --------------------------------------------------------------------------

      # Create .aws directory for credentials
      systemd.tmpfiles.rules = [
        "d /var/lib/hydra/queue-runner/.aws 0700 hydra-queue-runner hydra - -"
      ];

      # Ensure Hydra waits for Authentik LDAP if enabled
      systemd.services.hydra.after = lib.mkIf config.rat.services.authentik.ldap.enable [
        "authentik-ldap.service"
      ];

      # --------------------------------------------------------------------------
      # Network Configuration
      # --------------------------------------------------------------------------

      links = {
        hydra = {
          protocol = "http";
        };
        prometheus-hydra-notify = {
          protocol = "http";
        };
        prometheus-hydra-queue-runner = {
          protocol = "http";
        };
      };

      rat.services.traefik.routes.hydra = {
        enable = true;
        inherit (cfg) subdomain;
        serviceUrl = config.links.hydra.url;
      };

      # --------------------------------------------------------------------------
      # User and Permission Configuration
      # --------------------------------------------------------------------------

      # Allow hydra to build for the system
      users.users.hydra.extraGroups = ["nixbld"];
      users.users.hydra-www.extraGroups = ["nixbld"];
      users.users.hydra-queue-runner.extraGroups = ["nixbld"];

      # --------------------------------------------------------------------------
      # Nix Configuration
      # --------------------------------------------------------------------------

      nix.settings.allowed-uris = [
        "github:"
        "git+https://github.com/"
        "git+ssh://github.com/"
      ];
    })

    # ==========================================================================
    # IMPERMANENCE CONFIGURATION
    # ==========================================================================

    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/hydra";
            user = "hydra";
            group = "hydra";
          }
        ];
      };
    })
  ];
}

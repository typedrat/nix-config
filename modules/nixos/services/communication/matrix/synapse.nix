{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  inherit (config.rat.services) domainName;
  cfg = config.rat.services.matrix-synapse;
  impermanenceCfg = config.rat.impermanence;

  mkWellKnown = content: ''
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${content}';
  '';

  serverConfig = builtins.toJSON {
    "m.server" = "${cfg.subdomain}.${domainName}:443";
  };

  clientConfig = builtins.toJSON {
    "m.homeserver" = {
      "base_url" = "https://${cfg.subdomain}.${domainName}";
    };
    "m.identity_server" = {
      "base_url" = "https://vector.im";
    };
  };
in {
  options.rat.services.matrix-synapse = {
    enable = options.mkEnableOption "Synapse, the reference Matrix homeserver";
    subdomain = options.mkOption {
      type = types.str;
      default = "matrix";
      description = "The subdomain to use for Synapse";
    };
  };

  config = modules.mkIf cfg.enable {
    links = {
      matrix-well-known = {
        protocol = "http";
      };

      matrix-synapse = {
        protocol = "http";
      };
    };

    rat.services.traefik = {
      routes = {
        # Matrix well-known endpoints on the root domain
        matrix-well-known = {
          enable = true;
          subdomain = null;
          serviceUrl = config.links.matrix-well-known.url;
          path = "/.well-known/matrix";
          priority = 100;
        };

        # Matrix API endpoints on the root domain
        matrix-api = {
          enable = true;
          subdomain = null;
          serviceUrl = config.links.matrix-synapse.url;
          path = "/_matrix";
          priority = 100;
        };

        # Synapse client API on the root domain
        synapse-client = {
          enable = true;
          subdomain = null;
          serviceUrl = config.links.matrix-synapse.url;
          path = "/_synapse/client";
          priority = 100;
        };

        # Matrix homeserver on its subdomain (handles API routes)
        matrix-synapse = {
          enable = true;
          inherit (cfg) subdomain;
          serviceUrl = config.links.matrix-synapse.url;
          priority = 100;
        };
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.well-known = {
        listen = [
          {
            addr = config.links.matrix-well-known.ipv4;
            inherit (config.links.matrix-well-known) port;
          }
        ];
        locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
        locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      };
    };

    services.matrix-synapse = {
      enable = true;
      withJemalloc = true;

      extras = [
        "systemd"
        "postgres"
        "url-preview"
        "oidc"
      ];

      settings = {
        server_name = domainName;
        public_baseurl = "https://${cfg.subdomain}.${domainName}";

        listeners = [
          {
            bind_addresses = [config.links.matrix-synapse.ipv4];
            inherit (config.links.matrix-synapse) port;
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = ["client" "federation"];
                compress = true;
              }
            ];
          }
        ];
        password_config.enabled = false;

        federation_client_minimum_tls_version = "1.2";
        suppress_key_server_warning = true;
        user_directory.prefer_local_users = true;

        oembed.additional_providers = [
          (
            let
              providers = pkgs.fetchurl {
                url = "https://oembed.com/providers.json";
                hash = "sha256-JUQD/mHAu0wA9Lh6Z8tlZ4F4/CPVs3kJ8aNS7CbP0uc=";
              };
            in
              pkgs.runCommand "providers.json"
              {
                nativeBuildInputs = with pkgs; [jq];
              } ''
                # filter out entries that do not contain a schemes entry
                # Error in configuration at 'oembed.additional_providers.<item 0>.<item 22>.endpoints.<item 0>': 'schemes' is a required property
                # and have none http protocols: Unsupported oEmbed scheme (spotify) for pattern: spotify:*
                jq '[ ..|objects| select(.endpoints[0]|has("schemes")) | .endpoints[0].schemes=([ .endpoints[0].schemes[]|select(.|contains("http")) ]) ]' ${providers} > $out
              ''
          )
        ];
      };
    };

    services.postgresql = {
      enable = true;

      ensureUsers = [
        {
          name = "matrix-synapse";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = ["matrix-synapse"];
    };

    environment.persistence.${impermanenceCfg.persistDir} = modules.mkIf impermanenceCfg.enable {
      directories = [
        {
          directory = config.services.matrix-synapse.dataDir;
          user = "matrix-synapse";
          group = "matrix-synapse";
          mode = "0755";
        }
      ];
    };
  };
}

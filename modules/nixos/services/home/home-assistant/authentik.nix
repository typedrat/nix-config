{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.home-assistant;
  authentikCfg = cfg.authentik;
  inherit (config.rat.services) domainName;
  authentikSubdomain = config.rat.services.authentik.subdomain;
in {
  options.rat.services.home-assistant.authentik = {
    applicationSlug = options.mkOption {
      type = types.str;
      default = "home-assistant";
      description = "The application slug in Authentik.";
    };

    displayName = options.mkOption {
      type = types.str;
      default = "Authentik";
      description = "Display name for the authentication provider.";
    };
  };

  config = modules.mkIf cfg.enable {
    # Define SOPS secrets for OAuth credentials
    sops.secrets."home-assistant/oauth_client_id" = {
      sopsFile = ../../../../secrets/home-assistant.yaml;
      key = "oauth_client_id";
    };

    sops.secrets."home-assistant/oauth_client_secret" = {
      sopsFile = ../../../../secrets/home-assistant.yaml;
      key = "oauth_client_secret";
    };

    # Install hass-oidc-auth custom component
    rat.services.home-assistant.customComponents = with pkgs.home-assistant-custom-components; [
      auth_oidc
    ];

    # Add Authentik OIDC configuration to Home Assistant
    rat.services.home-assistant.config = lib.mkIf (cfg.config != null) {
      auth_oidc = {
        client_id = "!secret oauth_client_id";
        client_secret = "!secret oauth_client_secret";
        discovery_url = "https://${authentikSubdomain}.${domainName}/application/o/${authentikCfg.applicationSlug}/.well-known/openid-configuration";
        display_name = authentikCfg.displayName;

        # Map Authentik claims to Home Assistant user attributes
        claims = {
          username = "preferred_username";
          name = "name";
          email = "email";
        };
      };

      # Ensure trusted proxies are configured for Traefik
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
      };
    };
  };
}

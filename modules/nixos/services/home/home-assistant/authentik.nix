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
    # Install hass-oidc-auth custom component
    rat.services.home-assistant.customComponents = with pkgs.home-assistant-custom-components; [
      auth_oidc
    ];

    # Add Authentik OIDC configuration to Home Assistant
    rat.services.home-assistant.config.auth_oidc = {
      client_id = "!secret oauth_client_id";
      client_secret = "!secret oauth_client_secret";
      discovery_url = "https://${authentikSubdomain}.${domainName}/application/o/${authentikCfg.applicationSlug}/.well-known/openid-configuration";
      display_name = authentikCfg.displayName;

      # Map Authentik claims to Home Assistant user attributes
      # Valid options: username, display_name, groups
      claims = {
        username = "preferred_username";
        display_name = "name";
      };
    };
  };
}

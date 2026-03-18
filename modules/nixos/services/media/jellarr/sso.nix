{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  jellarrCfg = config.rat.services.jellarr;
  cfg = config.rat.services.jellarr.plugins.sso;

  providerType = types.submodule {
    options = {
      oidEndpoint = options.mkOption {
        type = types.str;
        description = "OIDC discovery endpoint URL for this provider.";
      };

      enabled = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether this OIDC provider is enabled.";
      };

      enableAuthorization = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable authorization for this provider.";
      };

      enableAllFolders = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether to grant new SSO users access to all folders.";
      };

      adminRoles = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles that grant Jellyfin admin privileges.";
      };

      roles = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles that are permitted to log in via this provider.";
      };

      defaultUsernameClaim = options.mkOption {
        type = types.nullOr types.str;
        default = "preferred_username";
        description = "OIDC claim to use as the Jellyfin username.";
      };

      roleClaim = options.mkOption {
        type = types.nullOr types.str;
        default = "groups";
        description = "OIDC claim used to determine roles.";
      };

      defaultProvider = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name of a provider to redirect to by default on the login page.";
      };

      schemeOverride = options.mkOption {
        type = types.nullOr types.str;
        default = "https";
        description = "Override the URL scheme used for redirect URIs (e.g. \"https\").";
      };

      doNotValidateEndpoints = options.mkOption {
        type = types.bool;
        default = false;
        description = "Skip validation of OIDC endpoints (use with caution).";
      };

      doNotValidateIssuerName = options.mkOption {
        type = types.bool;
        default = false;
        description = "Skip validation of the OIDC issuer name (use with caution).";
      };

      disableHttps = options.mkOption {
        type = types.bool;
        default = false;
        description = "Allow non-HTTPS OIDC endpoints (use with caution).";
      };

      folderRoleMapping = options.mkOption {
        type = types.listOf (types.submodule {
          options = {
            role = options.mkOption {
              type = types.str;
              description = "Role name to map to folders.";
            };
            folders = options.mkOption {
              type = types.listOf types.str;
              description = "Folder names accessible to this role.";
            };
          };
        });
        default = [];
        description = "List of role-to-folder mappings for granular library access control.";
      };
    };
  };

  mkProviderConfig = _name: provCfg: {
    OidEndpoint = provCfg.oidEndpoint;
    OidClientId = config.sops.placeholder."jellarr/sso/clientId";
    OidSecret = config.sops.placeholder."jellarr/sso/clientSecret";
    Enabled = provCfg.enabled;
    EnableAuthorization = provCfg.enableAuthorization;
    EnableAllFolders = provCfg.enableAllFolders;
    AdminRoles = provCfg.adminRoles;
    Roles = provCfg.roles;
    DefaultUsernameClaim = provCfg.defaultUsernameClaim;
    RoleClaim = provCfg.roleClaim;
    DefaultProvider = provCfg.defaultProvider;
    SchemeOverride = provCfg.schemeOverride;
    DoNotValidateEndpoints = provCfg.doNotValidateEndpoints;
    DoNotValidateIssuerName = provCfg.doNotValidateIssuerName;
    DisableHttps = provCfg.disableHttps;
    FolderRoleMapping = map (m: {
      Role = m.role;
      Folders = m.folders;
    }) provCfg.folderRoleMapping;
  };
in {
  options.rat.services.jellarr.plugins.sso = {
    enable = options.mkEnableOption "Jellyfin SSO/OIDC Authentication plugin";

    providers = options.mkOption {
      type = types.attrsOf providerType;
      default = {};
      description = ''
        OIDC provider configurations keyed by provider name. The name becomes
        the identifier in the SSO login URL path (e.g. /sso/OID/start/<name>).
      '';
    };
  };

  config = modules.mkIf (jellarrCfg.enable && cfg.enable) {
    sops.secrets."jellarr/sso/clientId" = {
      sopsFile = ../../../../../secrets/jellyfin.yaml;
      key = "clientId";
      owner = "jellarr";
      mode = "0400";
    };

    sops.secrets."jellarr/sso/clientSecret" = {
      sopsFile = ../../../../../secrets/jellyfin.yaml;
      key = "clientSecret";
      owner = "jellarr";
      mode = "0400";
    };

    rat.services.jellarr._jellarrPluginRepos = [
      {
        name = "SSO-Auth";
        url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
        enabled = true;
      }
    ];

    rat.services.jellarr._jellarrPlugins = [
      {
        name = "SSO-Auth";
        configuration = {
          SamlConfigs = {};
          OidConfigs = lib.mapAttrs mkProviderConfig cfg.providers;
        };
      }
    ];
  };
}

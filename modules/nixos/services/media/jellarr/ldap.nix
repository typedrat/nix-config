{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  jellarrCfg = config.rat.services.jellarr;
  cfg = config.rat.services.jellarr.plugins.ldap;
in {
  options.rat.services.jellarr.plugins.ldap = {
    enable = options.mkEnableOption "Jellyfin LDAP Authentication plugin";

    server = options.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "LDAP server hostname.";
    };

    port = options.mkOption {
      type = types.port;
      default = 3389;
      description = "LDAP server port.";
    };

    useSsl = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use SSL for the LDAP connection.";
    };

    useStartTls = options.mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use STARTTLS for the LDAP connection.";
    };

    baseDn = options.mkOption {
      type = types.str;
      default = "OU=jellyfin,DC=ldap,DC=goauthentik,DC=io";
      description = "LDAP base DN for user searches.";
    };

    bindUser = options.mkOption {
      type = types.str;
      default = "cn=ldap-search,ou=users,dc=ldap,dc=goauthentik,dc=io";
      description = "DN of the LDAP user used for binding/searching.";
    };

    searchFilter = options.mkOption {
      type = types.str;
      default = "(objectClass=user)";
      description = "LDAP search filter for users.";
    };

    adminFilter = options.mkOption {
      type = types.str;
      default = "";
      description = "LDAP search filter for admin users. Empty string disables admin filter.";
    };

    searchAttributes = options.mkOption {
      type = types.str;
      default = "uid, cn, mail, displayName";
      description = "Comma-separated list of LDAP attributes to search.";
    };

    uidAttribute = options.mkOption {
      type = types.str;
      default = "uid";
      description = "LDAP attribute used as the unique user identifier.";
    };

    usernameAttribute = options.mkOption {
      type = types.str;
      default = "cn";
      description = "LDAP attribute used as the Jellyfin username.";
    };

    createUsersFromLdap = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically create Jellyfin users from LDAP entries.";
    };

    enableAllFolders = options.mkOption {
      type = types.bool;
      default = true;
      description = "Whether to grant newly created LDAP users access to all folders.";
    };
  };

  config = modules.mkIf (jellarrCfg.enable && cfg.enable) {
    sops.secrets."jellarr/ldap/password" = {
      sopsFile = ../../../../../secrets/authentik.yaml;
      key = "ldap/password";
      owner = "jellarr";
      mode = "0400";
    };

    rat.services.jellarr._jellarrPlugins = [
      {
        name = "LDAP Authentication";
        configuration = {
          LdapServer = cfg.server;
          LdapPort = cfg.port;
          UseSsl = cfg.useSsl;
          UseStartTls = cfg.useStartTls;
          LdapBindUser = cfg.bindUser;
          LdapBindPassword = config.sops.placeholder."jellarr/ldap/password";
          LdapBaseDn = cfg.baseDn;
          LdapSearchFilter = cfg.searchFilter;
          LdapAdminFilter = cfg.adminFilter;
          LdapSearchAttributes = cfg.searchAttributes;
          LdapUidAttribute = cfg.uidAttribute;
          LdapUsernameAttribute = cfg.usernameAttribute;
          CreateUsersFromLdap = cfg.createUsersFromLdap;
          EnableAllFolders = cfg.enableAllFolders;
        };
      }
    ];
  };
}

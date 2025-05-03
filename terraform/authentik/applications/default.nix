{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  imports = [
    ./autobrr.nix
    ./grafana.nix
    ./lidarr.nix
    ./jellyfin.nix
    ./prometheus.nix
    ./prowlarr.nix
    ./qbittorrent.nix
    ./radarr.nix
    ./sonarr.nix
    ./traefik.nix
  ];

  commonAppOptions = {
    name = mkOption {
      type = types.str;
      description = "The display name of the application";
    };

    group = mkOption {
      type = types.str;
      description = "The group this application belongs to in the UI";
    };

    description = mkOption {
      type = types.str;
      default = "";
      description = "A description of the application";
    };

    icon = mkOption {
      type = types.str;
      description = "URL or path to the application icon";
    };

    accessGroups = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Groups that can access this application";
    };

    entitlements = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "The name of the entitlement";
          };

          groups = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Groups that have this entitlement";
          };
        };
      });
      default = [];
      description = "Entitlements for in-application permissions";
    };
  };

  ldapOptions = types.submodule {
    options = {
      baseDn = mkOption {
        type = types.str;
        description = "Base DN for LDAP searches";
      };

      bindMode = mkOption {
        type = types.enum ["direct" "cached"];
        default = "cached";
        description = "LDAP bind mode";
      };

      searchMode = mkOption {
        type = types.enum ["direct" "cached"];
        default = "cached";
        description = "LDAP search mode";
      };

      tlsServerName = mkOption {
        type = types.str;
        description = "TLS server name for LDAP";
      };
    };
  };

  oauth2Options = types.submodule {
    options = {
      clientId = mkOption {
        type = types.str;
        description = "OAuth2 client ID";
      };

      clientSecret = mkOption {
        type = types.str;
        description = "OAuth2 client secret";
      };

      redirectUris = mkOption {
        type = types.listOf (types.submodule {
          options = {
            url = mkOption {
              type = types.str;
              description = "Redirect URI";
            };
            matchingMode = mkOption {
              type = types.enum ["strict" "startsWith"];
              default = "strict";
              description = "URI matching mode";
            };
          };
        });
        description = "List of allowed redirect URIs";
      };

      launchUrl = mkOption {
        type = types.str;
        default = "";
        description = "URL to launch the application";
      };

      backchannelLdap = mkOption {
        type = types.nullOr ldapOptions;
        default = null;
        description = "LDAP configuration for backchannel authentication";
      };
    };
  };

  proxyOptions = types.submodule {
    options = {
      externalHost = mkOption {
        type = types.str;
        description = "External host URL for the proxy";
      };

      basicAuth = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable passing basic authentication to the proxied application";
        };
        username = mkOption {
          type = types.str;
          default = "username";
          description = "User/group attribute to use for username";
        };
        password = mkOption {
          type = types.str;
          default = "password";
          description = "User/group attribute to use for password";
        };
      };
    };
  };
in {
  inherit imports;

  options.authentik.applications = mkOption {
    type = types.attrsOf (types.submodule {
      options =
        commonAppOptions
        // {
          ldap = mkOption {
            type = types.nullOr ldapOptions;
            default = null;
            description = "LDAP provider configuration";
          };

          oauth2 = mkOption {
            type = types.nullOr oauth2Options;
            default = null;
            description = "OAuth2 provider configuration";
          };

          proxy = mkOption {
            type = types.nullOr proxyOptions;
            default = null;
            description = "Proxy provider configuration";
          };
        };
    });
    default = {};
    description = "Applications to configure in Authentik";
  };

  config = {
    resource = {
      authentik_provider_oauth2 = lib.mapAttrs' (
        name: cfg:
          lib.nameValuePair "${name}-oauth2" {
            name = "${cfg.name} (OAuth2)";
            authorization_flow = "\${ data.authentik_flow.default-authorization-flow.id }";
            invalidation_flow = "\${ data.authentik_flow.default-provider-invalidation-flow.id }";
            client_id = cfg.oauth2.clientId;
            client_secret = cfg.oauth2.clientSecret;
            allowed_redirect_uris =
              map (uri: {
                inherit (uri) url;
                matching_mode = uri.matchingMode;
              })
              cfg.oauth2.redirectUris;
            property_mappings = "\${ data.authentik_property_mapping_provider_scope.with-entitlements.ids }";
          }
      ) (lib.filterAttrs (_name: cfg: cfg.oauth2 != null) config.authentik.applications);

      authentik_provider_proxy = lib.mapAttrs' (
        name: cfg:
          lib.nameValuePair "${name}-proxy" {
            name = "${cfg.name} (Proxy)";
            external_host = cfg.proxy.externalHost;
            basic_auth_enabled = cfg.proxy.basicAuth.enable;
            basic_auth_username_attribute = lib.mkIf cfg.proxy.basicAuth.enable cfg.proxy.basicAuth.username;
            basic_auth_password_attribute = lib.mkIf cfg.proxy.basicAuth.enable cfg.proxy.basicAuth.password;
            mode = "forward_single";
            access_token_validity = "days=1";
            authorization_flow = "\${ data.authentik_flow.default-authorization-flow.id }";
            invalidation_flow = "\${ data.authentik_flow.default-provider-invalidation-flow.id }";
          }
      ) (lib.filterAttrs (_name: cfg: cfg.proxy != null) config.authentik.applications);

      authentik_provider_ldap = lib.mkMerge [
        # Primary LDAP providers
        (lib.mapAttrs' (
          name: cfg:
            lib.nameValuePair "${name}-ldap" {
              name = "${cfg.name} (LDAP)";
              base_dn = cfg.ldap.baseDn;
              bind_mode = cfg.ldap.bindMode;
              search_mode = cfg.ldap.searchMode;
              bind_flow = "\${ data.authentik_flow.default-authentication-flow.id }";
              unbind_flow = "\${ data.authentik_flow.default-invalidation-flow.id }";
              tls_server_name = cfg.ldap.tlsServerName;
            }
        ) (lib.filterAttrs (_name: cfg: cfg.ldap != null) config.authentik.applications))

        # Backchannel LDAP providers
        (lib.mapAttrs' (
            name: cfg:
              lib.nameValuePair "${name}-backchannel" {
                name = "${cfg.name} (LDAP Backchannel)";
                base_dn = cfg.oauth2.backchannelLdap.baseDn;
                bind_mode = cfg.oauth2.backchannelLdap.bindMode;
                search_mode = cfg.oauth2.backchannelLdap.searchMode;
                bind_flow = "\${ data.authentik_flow.default-authentication-flow.id }";
                unbind_flow = "\${ data.authentik_flow.default-invalidation-flow.id }";
                tls_server_name = cfg.oauth2.backchannelLdap.tlsServerName;
              }
          ) (lib.filterAttrs (
              _name: cfg:
                cfg.oauth2 != null && cfg.oauth2.backchannelLdap != null
            )
            config.authentik.applications))
      ];

      authentik_application =
        lib.mapAttrs (name: cfg: {
          inherit (cfg) name;
          slug = name;
          inherit (cfg) group;
          meta_icon = cfg.icon;
          meta_description = cfg.description;
          meta_launch_url =
            if cfg.oauth2 != null
            then cfg.oauth2.launchUrl
            else "";
          protocol_provider =
            if cfg.oauth2 != null
            then "\${ authentik_provider_oauth2.${name}-oauth2.id }"
            else if cfg.proxy != null
            then "\${ authentik_provider_proxy.${name}-proxy.id }"
            else "\${ authentik_provider_ldap.${name}-ldap.id }";
          backchannel_providers =
            lib.optional (cfg.oauth2 != null && cfg.oauth2.backchannelLdap != null)
            "\${ authentik_provider_ldap.${name}-backchannel.id }";
        })
        config.authentik.applications;

      authentik_application_entitlement = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            name: cfg:
              lib.imap0 (idx: entitlement: {
                name = "${name}-entitlement-${toString idx}";
                value = {
                  inherit (entitlement) name;
                  application = "\${ authentik_application.${name}.uuid }";
                };
              })
              cfg.entitlements
          )
          config.authentik.applications
        )
      );

      authentik_policy_binding = lib.mkMerge [
        # Application access bindings
        (lib.listToAttrs (
          lib.flatten (
            lib.mapAttrsToList (
              name: cfg:
                lib.imap0 (idx: group: {
                  name = "app-${name}-${group}-${toString idx}";
                  value = {
                    target = "\${ authentik_application.${name}.uuid }";
                    group = "\${ authentik_group.${group}.id }";
                    order = idx;
                  };
                })
                cfg.accessGroups
            )
            config.authentik.applications
          )
        ))

        # Entitlement policy bindings
        (
          lib.listToAttrs (
            lib.flatten (
              lib.mapAttrsToList (
                name: cfg:
                  lib.flatten (
                    lib.imap0 (
                      entIdx: entitlement:
                        lib.imap0 (grpIdx: group: {
                          name = "entitlement-${name}-${toString entIdx}-${group}-${toString grpIdx}";
                          value = {
                            target = "\${ authentik_application_entitlement.${name}-entitlement-${toString entIdx}.id }";
                            group = "\${ authentik_group.${group}.id }";
                            order = grpIdx;
                          };
                        })
                        entitlement.groups
                    )
                    cfg.entitlements
                  )
              )
              config.authentik.applications
            )
          )
        )

        # LDAP search access bindings
        (lib.mapAttrs' (
          name: _cfg:
            lib.nameValuePair "ldap-search-${name}" {
              target = "\${ authentik_application.${name}.uuid }";
              user = "\${ authentik_user.ldap-search.id }";
              order = 0;
            }
        ) (lib.filterAttrs (_name: cfg: cfg.ldap != null || (cfg.oauth2 != null && cfg.oauth2.backchannelLdap != null)) config.authentik.applications))
      ];
    };

    authentik.outposts = {
      ldap.providers =
        lib.mapAttrsToList (
          name: _cfg: "\${authentik_provider_ldap.${name}-ldap.id}"
        ) (lib.filterAttrs (_name: cfg: cfg.ldap != null) config.authentik.applications)
        ++ lib.mapAttrsToList (
          name: _cfg: "\${authentik_provider_ldap.${name}-backchannel.id}"
        ) (lib.filterAttrs (
            _name: cfg:
              cfg.oauth2 != null && cfg.oauth2.backchannelLdap != null
          )
          config.authentik.applications);

      proxy.providers = lib.mapAttrsToList (
        name: _cfg: "\${authentik_provider_proxy.${name}-proxy.id}"
      ) (lib.filterAttrs (_name: cfg: cfg.proxy != null) config.authentik.applications);
    };

    data.authentik_property_mapping_provider_scope.with-entitlements = {
      managed_list = [
        "goauthentik.io/providers/oauth2/scope-openid"
        "goauthentik.io/providers/oauth2/scope-email"
        "goauthentik.io/providers/oauth2/scope-profile"
        "goauthentik.io/providers/oauth2/scope-entitlements"
      ];
    };
  };
}

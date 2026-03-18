# Jellarr NixOS Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declaratively configure Jellyfin via Jellarr with typed Nix options for LDAP auth, SSO/OIDC, and Shokofin plugins.

**Architecture:** A custom systemd service (not the upstream NixOS module) using the upstream Jellarr package. Config YAML is built as a SOPS template with secret placeholders. Plugin sub-modules contribute to internal `_jellarrPlugins` and `_jellarrPluginRepos` options that the base module assembles into the final YAML. A separate bootstrap oneshot injects the API key into Jellyfin's SQLite DB.

**Tech Stack:** NixOS module system, SOPS-nix, systemd, Jellarr (TypeScript/Node.js)

**Spec:** `docs/superpowers/specs/2026-03-17-jellarr-module-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `flake.nix` | Modify | Add `jellarr` flake input |
| `modules/nixos/services/media/jellarr/default.nix` | Create | Base module: options, internal plugin mechanism, YAML assembly, systemd services, SOPS secrets, impermanence |
| `modules/nixos/services/media/jellarr/ldap.nix` | Create | LDAP Auth plugin typed options + config generation |
| `modules/nixos/services/media/jellarr/sso.nix` | Create | SSO/OIDC plugin typed options + config generation |
| `modules/nixos/services/media/jellarr/shokofin.nix` | Create | Shokofin plugin typed options + config generation |
| `modules/nixos/services/media/default.nix` | Modify | Add `./jellarr` to imports |
| `systems/iserlohn/default.nix` | Modify | Enable and configure `rat.services.jellarr` |
| `secrets/jellyfin.yaml` | Modify | Add `jellarr/apiKey` and `jellarr/shokofin/apiKey` keys |

---

### Task 1: Add Jellarr Flake Input

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add the jellarr input to the `#region Software Outside of Nixpkgs` section**

In `flake.nix`, add after the `fenix` input block (around line 211):

```nix
jellarr = {
  url = "github:venkyr77/jellarr";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

- [ ] **Step 2: Run `nix flake update jellarr` to fetch the lock entry**

Run: `nix flake update jellarr`
Expected: Lock file updated, no errors.

- [ ] **Step 3: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat: add jellarr flake input"
```

---

### Task 2: Create Base Module (`default.nix`)

**Files:**
- Create: `modules/nixos/services/media/jellarr/default.nix`

This is the largest task. It defines all base options, internal plugin mechanism, YAML template assembly, systemd services, SOPS secrets, user/group, and impermanence.

- [ ] **Step 1: Create the module directory**

Run: `mkdir -p modules/nixos/services/media/jellarr`

- [ ] **Step 2: Write `default.nix`**

```nix
{
  config,
  inputs',
  lib,
  pkgs,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellarr;
  impermanenceCfg = config.rat.impermanence;

  jellarrSecretsFile = ../../../../../secrets/jellyfin.yaml;

  libraryType = types.submodule {
    options = {
      name = options.mkOption {
        type = types.str;
        description = "Library display name.";
      };
      collectionType = options.mkOption {
        type = types.enum ["movies" "tvshows" "music" "homevideos" "musicvideos" "boxsets" "books" "mixed"];
        description = "Jellyfin collection type.";
      };
      paths = options.mkOption {
        type = types.listOf types.str;
        description = "Media directory paths for this library.";
      };
    };
  };

  # Assemble the full config as a Nix attrset, then serialize via builtins.toJSON.
  # JSON is valid YAML, so Jellarr parses it directly. SOPS placeholders are
  # embedded as string values and substituted at activation time.
  enc = cfg.encoding;

  jellarrConfig = {
    version = 1;
    base_url = config.links.jellyfin.url;
    system = {
      enableMetrics = true;
      pluginRepositories = [
        {
          name = "Jellyfin Official";
          url = "https://repo.jellyfin.org/releases/plugin/manifest.json";
          enabled = true;
        }
      ] ++ cfg._jellarrPluginRepos;
      trickplayOptions = {
        enableHwAcceleration = true;
        enableHwEncoding = true;
      };
    };
  }
  // lib.optionalAttrs enc.enable {
    encoding = {
      inherit (enc) enableHardwareEncoding hardwareAccelerationType hardwareDecodingCodecs;
      inherit (enc) enableDecodingColorDepth10Hevc enableDecodingColorDepth10HevcRext;
      inherit (enc) enableDecodingColorDepth12HevcRext enableDecodingColorDepth10Vp9;
      inherit (enc) allowHevcEncoding allowAv1Encoding;
    };
  }
  // {
    library.virtualFolders = map (l: {
      inherit (l) name collectionType;
      libraryOptions.pathInfos = map (p: {path = p;}) l.paths;
    }) cfg.libraries;

    branding = {
      inherit (cfg.branding) splashscreenEnabled;
    }
    // lib.optionalAttrs (cfg.branding.loginDisclaimer != null) {
      inherit (cfg.branding) loginDisclaimer;
    }
    // lib.optionalAttrs (cfg.branding.customCss != null) {
      inherit (cfg.branding) customCss;
    };

    startup = {
      inherit (cfg) completeStartupWizard;
    };

    plugins = cfg._jellarrPlugins;
  };
in {
  imports = [
    ./ldap.nix
    ./sso.nix
    ./shokofin.nix
  ];

  options.rat.services.jellarr = {
    enable = options.mkEnableOption "Jellarr";

    subdomain = options.mkOption {
      type = types.str;
      default = "jellyfin";
      description = "The subdomain for Jellyfin (reused from Jellyfin service).";
    };

    completeStartupWizard = options.mkOption {
      type = types.bool;
      default = true;
      description = "Automatically complete the Jellyfin startup wizard.";
    };

    encoding = {
      enable = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable encoding/transcoding configuration.";
      };
      hardwareAccelerationType = options.mkOption {
        type = types.enum ["none" "amf" "qsv" "nvenc" "v4l2m2m" "vaapi" "videotoolbox" "rkmpp"];
        default = "nvenc";
        description = "Hardware acceleration type.";
      };
      hardwareDecodingCodecs = options.mkOption {
        type = types.listOf types.str;
        default = ["h264" "hevc" "mpeg2video" "vc1" "vp8" "vp9"];
        description = "Codecs to hardware-decode.";
      };
      enableDecodingColorDepth10Hevc = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit HEVC decoding.";
      };
      enableDecodingColorDepth10HevcRext = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit HEVC RExt decoding.";
      };
      enableDecodingColorDepth12HevcRext = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enable 12-bit HEVC RExt decoding.";
      };
      enableDecodingColorDepth10Vp9 = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit VP9 decoding.";
      };
      allowHevcEncoding = options.mkOption {
        type = types.bool;
        default = true;
        description = "Allow HEVC encoding.";
      };
      allowAv1Encoding = options.mkOption {
        type = types.bool;
        default = false;
        description = "Allow AV1 encoding.";
      };
      enableHardwareEncoding = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable hardware encoding.";
      };
    };

    libraries = options.mkOption {
      type = types.listOf libraryType;
      default = [];
      description = "Jellyfin media libraries to configure.";
    };

    branding = {
      loginDisclaimer = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Login page disclaimer HTML.";
      };
      customCss = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom CSS for Jellyfin.";
      };
      splashscreenEnabled = options.mkOption {
        type = types.bool;
        default = false;
        description = "Enable splash screen.";
      };
    };

    # Internal options: plugin sub-modules append typed attrsets.
    # These are serialized to JSON (valid YAML) along with the rest of the config.
    _jellarrPlugins = options.mkOption {
      type = let jsonType = (pkgs.formats.json {}).type; in types.listOf jsonType;
      default = [];
      internal = true;
      description = "Internal: plugin configurations collected from sub-modules.";
    };

    _jellarrPluginRepos = options.mkOption {
      type = let jsonType = (pkgs.formats.json {}).type; in types.listOf jsonType;
      default = [];
      internal = true;
      description = "Internal: plugin repository entries collected from sub-modules.";
    };
  };

  config = modules.mkMerge [
    (modules.mkIf cfg.enable {
      # SOPS secrets
      sops.secrets."jellarr/apiKey" = {
        sopsFile = jellarrSecretsFile;
        key = "jellarr/apiKey";
        owner = "jellarr";
        group = "jellyfin";
        mode = "0440";
      };

      # SOPS templates
      sops.templates."jellarr.yml" = {
        content = builtins.toJSON jellarrConfig;
        owner = "jellarr";
        group = "jellarr";
        mode = "0400";
      };

      sops.templates."jellarr.env" = {
        content = "JELLARR_API_KEY=${config.sops.placeholder."jellarr/apiKey"}";
        owner = "jellarr";
        group = "jellarr";
        mode = "0400";
      };

      # User/group
      users.users.jellarr = {
        isSystemUser = true;
        group = "jellarr";
        home = "/var/lib/jellarr";
        createHome = true;
      };

      users.groups.jellarr = {};

      systemd.tmpfiles.rules = [
        "d /var/lib/jellarr 0750 jellarr jellarr -"
        "d /var/lib/jellarr/config 0750 jellarr jellarr -"
      ];

      # Bootstrap service: inject API key into Jellyfin's SQLite DB
      systemd.services.jellarr-bootstrap = {
        description = "Jellarr bootstrap: inject API key into Jellyfin DB";
        after = ["jellyfin.service"];
        path = [pkgs.sqlite];

        serviceConfig = {
          Type = "oneshot";
          User = config.services.jellyfin.user;
          Group = config.services.jellyfin.group;
          RemainAfterExit = true;
        };

        script = let
          db = "${config.services.jellyfin.dataDir}/data/jellyfin.db";
          apiKeyFile = config.sops.secrets."jellarr/apiKey".path;
        in ''
          API_KEY=$(cat ${apiKeyFile})

          # Validate key is hex-only to prevent SQL injection
          if ! echo "$API_KEY" | grep -qE '^[0-9a-fA-F]+$'; then
            echo "ERROR: API key contains unexpected characters" >&2
            exit 1
          fi

          # Check if the key already exists
          EXISTING=$(sqlite3 ${db} "SELECT COUNT(*) FROM ApiKeys WHERE AccessToken = '$API_KEY';")
          if [ "$EXISTING" = "0" ]; then
            sqlite3 ${db} "INSERT INTO ApiKeys (DateCreated, DateLastActivity, Name, AccessToken) VALUES (datetime('now'), datetime('now'), 'Jellarr', '$API_KEY');"
            echo "Jellarr API key inserted into Jellyfin DB."
          else
            echo "Jellarr API key already exists in Jellyfin DB."
          fi
        '';
      };

      # Main service
      systemd.services.jellarr = {
        description = "Jellarr: declarative Jellyfin configuration";
        after = ["jellyfin.service" "jellarr-bootstrap.service" "network-online.target"];
        wants = ["jellyfin.service" "jellarr-bootstrap.service"];
        requires = ["network-online.target"];
        path = [pkgs.curl];

        serviceConfig = {
          Type = "oneshot";
          User = "jellarr";
          Group = "jellarr";
          WorkingDirectory = "/var/lib/jellarr";
          EnvironmentFile = config.sops.templates."jellarr.env".path;
        };

        preStart = ''
          # Wait for Jellyfin to be healthy
          for i in $(seq 1 120); do
            if curl -sf "${config.links.jellyfin.url}/health" > /dev/null 2>&1; then
              break
            fi
            if [ "$i" = "120" ]; then
              echo "Jellyfin did not become healthy within 120 seconds"
              exit 1
            fi
            sleep 1
          done

          # Install config from SOPS template
          install -m 0400 ${config.sops.templates."jellarr.yml".path} /var/lib/jellarr/config/config.yml
        '';

        script = ''
          exec ${inputs'.jellarr.packages.default}/bin/jellarr
        '';
      };

      # Timer
      systemd.timers.jellarr = {
        description = "Run Jellarr daily";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "daily";
          RandomizedDelaySec = "5m";
          Persistent = true;
          Unit = "jellarr.service";
        };
      };
    })
    (modules.mkIf (cfg.enable && impermanenceCfg.enable) {
      environment.persistence.${impermanenceCfg.persistDir} = {
        directories = [
          {
            directory = "/var/lib/jellarr";
            user = "jellarr";
            group = "jellarr";
          }
        ];
      };
    })
  ];
}
```

- [ ] **Step 3: Verify the file evaluates (basic syntax check)**

Run: `nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath 2>&1 | head -5`
Expected: Likely errors about missing plugin sub-modules (ldap.nix, sso.nix, shokofin.nix) — that's fine, they're created in subsequent tasks. Just verify there are no syntax errors in `default.nix` itself.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/services/media/jellarr/default.nix
git commit -m "feat(jellarr): add base module with options, YAML assembly, and systemd services"
```

---

### Task 3: Create LDAP Plugin Module (`ldap.nix`)

**Files:**
- Create: `modules/nixos/services/media/jellarr/ldap.nix`

- [ ] **Step 1: Write `ldap.nix`**

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellarr.plugins.ldap;
  jellarrCfg = config.rat.services.jellarr;
in {
  options.rat.services.jellarr.plugins.ldap = {
    enable = options.mkEnableOption "LDAP Authentication plugin for Jellarr";

    server = options.mkOption {
      type = types.str;
      default = "localhost";
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
      description = "Use SSL for LDAP connection.";
    };

    useStartTls = options.mkOption {
      type = types.bool;
      default = false;
      description = "Use StartTLS for LDAP connection.";
    };

    baseDn = options.mkOption {
      type = types.str;
      default = "OU=jellyfin,DC=ldap,DC=goauthentik,DC=io";
      description = "LDAP search base DN.";
    };

    bindUser = options.mkOption {
      type = types.str;
      default = "cn=ldap-search,ou=users,dc=ldap,dc=goauthentik,dc=io";
      description = "LDAP bind user DN.";
    };

    searchFilter = options.mkOption {
      type = types.str;
      default = "(objectClass=user)";
      description = "LDAP search filter.";
    };

    adminFilter = options.mkOption {
      type = types.str;
      default = "";
      description = "LDAP admin filter.";
    };

    searchAttributes = options.mkOption {
      type = types.str;
      default = "uid, cn, mail, displayName";
      description = "LDAP attributes to search.";
    };

    uidAttribute = options.mkOption {
      type = types.str;
      default = "uid";
      description = "LDAP UID attribute.";
    };

    usernameAttribute = options.mkOption {
      type = types.str;
      default = "cn";
      description = "LDAP username attribute.";
    };

    createUsersFromLdap = options.mkOption {
      type = types.bool;
      default = true;
      description = "Auto-create Jellyfin users from LDAP.";
    };

    enableAllFolders = options.mkOption {
      type = types.bool;
      default = true;
      description = "Grant LDAP-created users access to all libraries.";
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
```

- [ ] **Step 2: Commit**

```bash
git add modules/nixos/services/media/jellarr/ldap.nix
git commit -m "feat(jellarr): add LDAP Auth plugin module"
```

---

### Task 4: Create SSO Plugin Module (`sso.nix`)

**Files:**
- Create: `modules/nixos/services/media/jellarr/sso.nix`

- [ ] **Step 1: Write `sso.nix`**

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellarr.plugins.sso;
  jellarrCfg = config.rat.services.jellarr;

  jellarrSecretsFile = ../../../../../secrets/jellyfin.yaml;

  providerType = types.submodule {
    options = {
      oidEndpoint = options.mkOption {
        type = types.str;
        description = "OIDC discovery endpoint URL.";
      };

      enabled = options.mkOption {
        type = types.bool;
        default = true;
        description = "Whether this provider is enabled.";
      };

      enableAuthorization = options.mkOption {
        type = types.bool;
        default = true;
        description = "Enable authorization.";
      };

      enableAllFolders = options.mkOption {
        type = types.bool;
        default = true;
        description = "Grant access to all libraries.";
      };

      adminRoles = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles that grant admin access.";
      };

      roles = options.mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Roles that grant access.";
      };

      defaultUsernameClaim = options.mkOption {
        type = types.nullOr types.str;
        default = "preferred_username";
        description = "Claim to use as username.";
      };

      roleClaim = options.mkOption {
        type = types.nullOr types.str;
        default = "groups";
        description = "Claim containing role information.";
      };

      defaultProvider = options.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default auth provider for SSO-created users.";
      };

      schemeOverride = options.mkOption {
        type = types.nullOr types.str;
        default = "https";
        description = "Scheme override for redirect URLs.";
      };

      doNotValidateEndpoints = options.mkOption {
        type = types.bool;
        default = false;
        description = "Skip OIDC endpoint validation.";
      };

      doNotValidateIssuerName = options.mkOption {
        type = types.bool;
        default = false;
        description = "Skip issuer name validation.";
      };

      disableHttps = options.mkOption {
        type = types.bool;
        default = false;
        description = "Disable HTTPS requirement.";
      };

      folderRoleMapping = options.mkOption {
        type = types.listOf (types.submodule {
          options = {
            role = options.mkOption {
              type = types.str;
              description = "Role name.";
            };
            folders = options.mkOption {
              type = types.listOf types.str;
              description = "Folder IDs to grant access to.";
            };
          };
        });
        default = [];
        description = "Role-to-folder access mapping.";
      };
    };
  };

  mkProviderConfig = name: provCfg: {
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
    enable = options.mkEnableOption "SSO/OIDC plugin for Jellarr";

    providers = options.mkOption {
      type = types.attrsOf providerType;
      default = {};
      description = "OIDC providers keyed by name (e.g. 'authentik').";
    };
  };

  config = modules.mkIf (jellarrCfg.enable && cfg.enable) {
    sops.secrets."jellarr/sso/clientId" = {
      sopsFile = jellarrSecretsFile;
      key = "clientId";
      owner = "jellarr";
      mode = "0400";
    };

    sops.secrets."jellarr/sso/clientSecret" = {
      sopsFile = jellarrSecretsFile;
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
```

- [ ] **Step 2: Commit**

```bash
git add modules/nixos/services/media/jellarr/sso.nix
git commit -m "feat(jellarr): add SSO/OIDC plugin module"
```

---

### Task 5: Create Shokofin Plugin Module (`shokofin.nix`)

**Files:**
- Create: `modules/nixos/services/media/jellarr/shokofin.nix`

- [ ] **Step 1: Write `shokofin.nix`**

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib) modules options types;
  cfg = config.rat.services.jellarr.plugins.shokofin;
  jellarrCfg = config.rat.services.jellarr;

  jellarrSecretsFile = ../../../../../secrets/jellyfin.yaml;

  titleProviderEnum = types.enum ["Shoko" "AniDB" "TMDB"];
  titleLanguageEnum = types.enum ["Romaji" "English" "Japanese" "Default"];
  descriptionProviderEnum = types.enum ["Shoko" "AniDB" "TMDB"];
in {
  options.rat.services.jellarr.plugins.shokofin = {
    enable = options.mkEnableOption "Shokofin plugin for Jellarr";

    # Connection
    url = options.mkOption {
      type = types.str;
      default = config.links.shoko.url;
      defaultText = lib.literalExpression "config.links.shoko.url";
      description = "Shoko server URL.";
    };

    username = options.mkOption {
      type = types.str;
      default = "Default";
      description = "Shoko username.";
    };

    # Library structure
    libraryOperationMode = options.mkOption {
      type = types.enum ["VFS" "Direct"];
      default = "VFS";
      description = "Library operation mode.";
    };

    useGroupsForShows = options.mkOption {
      type = types.bool;
      default = false;
      description = "Use Shoko groups for shows.";
    };

    separateMovies = options.mkOption {
      type = types.bool;
      default = false;
      description = "Separate movies from shows.";
    };

    filterMovieLibraries = options.mkOption {
      type = types.bool;
      default = true;
      description = "Filter non-movies in movie libraries.";
    };

    addTrailers = options.mkOption {
      type = types.bool;
      default = true;
      description = "Include trailers.";
    };

    addMissingMetadata = options.mkOption {
      type = types.bool;
      default = true;
      description = "Include missing entries.";
    };

    # VFS
    vfs = {
      threads = options.mkOption {
        type = types.int;
        default = 4;
        description = "Concurrent VFS link generation threads.";
      };

      addReleaseGroup = options.mkOption {
        type = types.bool;
        default = false;
        description = "Add release group to VFS filenames.";
      };

      addResolution = options.mkOption {
        type = types.bool;
        default = false;
        description = "Add resolution to VFS filenames.";
      };

      resolveLinks = options.mkOption {
        type = types.bool;
        default = false;
        description = "Follow symlinks in VFS.";
      };
    };

    # Titles
    titleMainOrder = options.mkOption {
      type = types.listOf titleProviderEnum;
      default = ["Shoko" "AniDB" "TMDB"];
      description = "Title provider priority.";
    };

    titleMainList = options.mkOption {
      type = types.listOf titleLanguageEnum;
      default = ["Romaji" "English" "Default"];
      description = "Title language priority.";
    };

    titleAlternateOrder = options.mkOption {
      type = types.listOf titleProviderEnum;
      default = ["Shoko" "AniDB" "TMDB"];
      description = "Alternate title provider priority.";
    };

    titleAlternateList = options.mkOption {
      type = types.listOf titleLanguageEnum;
      default = ["English" "Romaji" "Japanese" "Default"];
      description = "Alternate title language priority.";
    };

    # Descriptions
    descriptionSourceOrder = options.mkOption {
      type = types.listOf descriptionProviderEnum;
      default = ["AniDB" "TMDB" "Shoko"];
      description = "Description provider priority.";
    };

    synopsisEnableMarkdown = options.mkOption {
      type = types.bool;
      default = true;
      description = "Enable markdown in descriptions.";
    };

    synopsisCleanLinks = options.mkOption {
      type = types.bool;
      default = true;
      description = "Clean links in descriptions.";
    };

    synopsisCleanMiscLines = options.mkOption {
      type = types.bool;
      default = true;
      description = "Clean misc lines in descriptions.";
    };

    synopsisRemoveSummary = options.mkOption {
      type = types.bool;
      default = true;
      description = "Remove summaries from descriptions.";
    };

    # Tags & Genres
    hideUnverifiedTags = options.mkOption {
      type = types.bool;
      default = true;
      description = "Hide unverified tags.";
    };

    tagMaximumDepth = options.mkOption {
      type = types.int;
      default = 0;
      description = "Maximum tag depth.";
    };

    genreMaximumDepth = options.mkOption {
      type = types.int;
      default = 1;
      description = "Maximum genre depth.";
    };

    addAniDBId = options.mkOption {
      type = types.bool;
      default = true;
      description = "Include AniDB ID in metadata.";
    };

    addTMDBId = options.mkOption {
      type = types.bool;
      default = false;
      description = "Include TMDB ID in metadata.";
    };

    # SignalR
    signalrAutoConnect = options.mkOption {
      type = types.bool;
      default = true;
      description = "Auto-connect SignalR.";
    };

    signalrRefreshEnabled = options.mkOption {
      type = types.bool;
      default = true;
      description = "Refresh on metadata changes.";
    };

    signalrFileEvents = options.mkOption {
      type = types.bool;
      default = true;
      description = "File event notifications.";
    };

    # Collections
    autoMergeVersions = options.mkOption {
      type = types.bool;
      default = true;
      description = "Auto-merge alternate versions.";
    };

    autoReconstructCollections = options.mkOption {
      type = types.bool;
      default = true;
      description = "Rebuild collections after scans.";
    };

    collectionMinSizeOfTwo = options.mkOption {
      type = types.bool;
      default = true;
      description = "Require minimum 2 entries for collections.";
    };
  };

  config = modules.mkIf (jellarrCfg.enable && cfg.enable) {
    sops.secrets."jellarr/shokofin/apiKey" = {
      sopsFile = jellarrSecretsFile;
      key = "jellarr/shokofin/apiKey";
      owner = "jellarr";
      mode = "0400";
    };

    rat.services.jellarr._jellarrPluginRepos = [
      {
        name = "Shokofin";
        url = "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json";
        enabled = true;
      }
    ];

    rat.services.jellarr._jellarrPlugins = [
      {
        name = "Shoko";
        configuration = {
          Url = cfg.url;
          Username = cfg.username;
          ApiKey = config.sops.placeholder."jellarr/shokofin/apiKey";

          DefaultLibraryOperationMode = cfg.libraryOperationMode;
          UseGroupsForShows = cfg.useGroupsForShows;
          SeparateMovies = cfg.separateMovies;
          FilterMovieLibraries = cfg.filterMovieLibraries;
          AddTrailers = cfg.addTrailers;
          AddMissingMetadata = cfg.addMissingMetadata;

          VFS_Threads = cfg.vfs.threads;
          VFS_AddReleaseGroup = cfg.vfs.addReleaseGroup;
          VFS_AddResolution = cfg.vfs.addResolution;
          VFS_ResolveLinks = cfg.vfs.resolveLinks;

          TitleMainOrder = cfg.titleMainOrder;
          TitleMainList = cfg.titleMainList;
          TitleAlternateOrder = cfg.titleAlternateOrder;
          TitleAlternateList = cfg.titleAlternateList;

          DescriptionSourceOrder = cfg.descriptionSourceOrder;
          SynopsisEnableMarkdown = cfg.synopsisEnableMarkdown;
          SynopsisCleanLinks = cfg.synopsisCleanLinks;
          SynopsisCleanMiscLines = cfg.synopsisCleanMiscLines;
          SynopsisRemoveSummary = cfg.synopsisRemoveSummary;

          HideUnverifiedTags = cfg.hideUnverifiedTags;
          TagMaximumDepth = cfg.tagMaximumDepth;
          GenreMaximumDepth = cfg.genreMaximumDepth;
          AddAniDBId = cfg.addAniDBId;
          AddTMDBId = cfg.addTMDBId;

          SignalR_AutoConnectEnabled = cfg.signalrAutoConnect;
          SignalR_RefreshEnabled = cfg.signalrRefreshEnabled;
          SignalR_FileEvents = cfg.signalrFileEvents;

          AutoMergeVersions = cfg.autoMergeVersions;
          AutoReconstructCollections = cfg.autoReconstructCollections;
          CollectionMinSizeOfTwo = cfg.collectionMinSizeOfTwo;
        };
      }
    ];
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/nixos/services/media/jellarr/shokofin.nix
git commit -m "feat(jellarr): add Shokofin plugin module"
```

---

### Task 6: Wire Up Imports

**Files:**
- Modify: `modules/nixos/services/media/default.nix`

- [ ] **Step 1: Add `./jellarr` to the imports list**

In `modules/nixos/services/media/default.nix`, add `./jellarr` to the imports list (alphabetically after `./dispatcharr`):

```nix
./jellarr
```

- [ ] **Step 2: Verify evaluation still works**

Run: `nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath 2>&1 | head -5`
Expected: Derivation path or evaluation errors unrelated to jellarr (since it's not enabled yet).

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/services/media/default.nix
git commit -m "feat(jellarr): wire up module imports"
```

---

### Task 7: Add SOPS Secrets

**Files:**
- Modify: `secrets/jellyfin.yaml`

- [ ] **Step 1: Generate a Jellarr API key**

Run: `openssl rand -hex 32`
Save the output — this is the `jellarr/apiKey` value.

- [ ] **Step 2: Get a Shokofin API key from Shoko**

Get an API key from the running Shoko instance:
Run: `ssh iserlohn -- "sudo cat /var/lib/shoko/settings-server.json" | jq -r '.AniDb.Username'`
Then use the Shoko API to generate an API key, or extract one from the Shoko web UI's settings page.

- [ ] **Step 3: Add keys to `secrets/jellyfin.yaml` via sops**

Run: `sops secrets/jellyfin.yaml`

Add these keys:
```yaml
jellarr/apiKey: <generated hex key>
jellarr/shokofin/apiKey: <shoko api key>
```

- [ ] **Step 4: Commit**

```bash
git add secrets/jellyfin.yaml
git commit -m "feat(jellarr): add SOPS secrets for API key and Shokofin"
```

---

### Task 8: Enable on Iserlohn

**Files:**
- Modify: `systems/iserlohn/default.nix`

- [ ] **Step 1: Add the jellarr configuration block**

In `systems/iserlohn/default.nix`, inside the `rat.services` block, add after `configarr.enable = true;`:

```nix
jellarr = {
  enable = true;

  libraries = [
    {
      name = "Movies";
      collectionType = "movies";
      paths = ["/mnt/media/movies"];
    }
    {
      name = "TV Shows";
      collectionType = "tvshows";
      paths = ["/mnt/media/tv-shows"];
    }
    {
      name = "TV Slop";
      collectionType = "tvshows";
      paths = ["/mnt/media/tv-slop"];
    }
    {
      name = "Anime";
      collectionType = "tvshows";
      paths = ["/mnt/media/anime" "/mnt/media/anime-movies"];
    }
    {
      name = "Music";
      collectionType = "music";
      paths = ["/mnt/media/music"];
    }
  ];

  plugins = {
    ldap.enable = true;
    sso = {
      enable = true;
      providers.authentik = {
        oidEndpoint = "https://auth.thisratis.gay/application/o/jellyfin/.well-known/openid-configuration";
      };
    };
    shokofin.enable = true;
  };
};
```

- [ ] **Step 2: Verify full evaluation**

Run: `nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath`
Expected: A derivation path (no errors).

- [ ] **Step 3: Commit**

```bash
git add systems/iserlohn/default.nix
git commit -m "feat(jellarr): enable on iserlohn with libraries and plugins"
```

---

### Task 9: Format, Build, and Deploy

- [ ] **Step 1: Format all code**

Run: `nix fmt`

- [ ] **Step 2: Commit formatting fixes if any**

```bash
git add -A
git commit -m "style: format jellarr module files"
```

- [ ] **Step 3: Build the iserlohn configuration**

Run: `nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel`
Expected: Build succeeds.

- [ ] **Step 4: Deploy to iserlohn**

Run: `nix run .#switch iserlohn -- --build-host iserlohn`
Expected: Successful deployment. The jellarr-bootstrap service injects the API key, the timer is installed, and the main service runs on its first trigger.

- [ ] **Step 5: Verify the service is working**

Run: `ssh iserlohn -- "sudo systemctl status jellarr-bootstrap && sudo systemctl status jellarr.timer"`
Expected: Bootstrap shows succeeded, timer is active.

- [ ] **Step 6: Trigger a manual run to test**

Run: `ssh iserlohn -- "sudo systemctl start jellarr"`
Then check logs: `ssh iserlohn -- "sudo journalctl -u jellarr -n 30 --no-pager"`
Expected: Jellarr runs, configures Jellyfin via API, exits successfully.

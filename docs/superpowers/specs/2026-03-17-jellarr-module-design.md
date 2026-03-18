# Jellarr NixOS Module Design

Declarative Jellyfin configuration management via [Jellarr](https://github.com/venkyr77/jellarr), with typed Nix options for LDAP auth, SSO/OIDC, and Shokofin plugins.

## Overview

Jellarr is a TypeScript tool that applies YAML-defined settings to a Jellyfin server via its REST API. The upstream flake provides a NixOS module (`nixosModules.default`) handling the systemd oneshot service, timer, user/group creation, and a bootstrap feature for API key injection.

This design wraps the upstream module with `rat.services.jellarr.*` options following existing patterns (SOPS templates, `links.*` service discovery, impermanence, traefik routes). Each plugin gets typed Nix options that generate the corresponding Jellarr YAML plugin configuration block.

## File Structure

```
modules/nixos/services/media/jellarr/
├── default.nix      # Base module: service wiring, encoding, libraries, branding, YAML assembly
├── ldap.nix         # LDAP Auth plugin typed options
├── sso.nix          # SSO/OIDC plugin typed options
└── shokofin.nix     # Shokofin plugin typed options
```

Additionally:
- `modules/nixos/services/media/default.nix` — add `./jellarr` import
- `systems/iserlohn/default.nix` — enable `rat.services.jellarr`
- `flake.nix` — add `jellarr` flake input
- `systems/default.nix` — import `inputs.jellarr.nixosModules.default` in shared modules

## Flake Input

```nix
jellarr = {
  url = "github:venkyr77/jellarr";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Added to the `#region Software Outside of Nixpkgs` section.

## `default.nix` — Base Module

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `rat.services.jellarr.enable` | bool | `false` | Enable Jellarr |
| `.subdomain` | string | `"jellyfin"` | Subdomain (reuses Jellyfin's) |
| `.completeStartupWizard` | bool | `true` | Auto-complete Jellyfin startup wizard |

#### Encoding (`rat.services.jellarr.encoding`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.enable` | bool | `true` | Enable encoding config |
| `.hardwareAccelerationType` | enum | `"nvenc"` | HW accel type |
| `.hardwareDecodingCodecs` | list of str | `["h264" "hevc" "mpeg2video" "vc1" "vp8" "vp9"]` | Pascal-supported decode codecs |
| `.enableDecodingColorDepth10Hevc` | bool | `true` | 10-bit HEVC decode |
| `.enableDecodingColorDepth10Vp9` | bool | `true` | 10-bit VP9 decode |
| `.allowHevcEncoding` | bool | `true` | HEVC encode (Pascal supports) |
| `.allowAv1Encoding` | bool | `false` | AV1 encode (Pascal cannot) |
| `.enableHardwareEncoding` | bool | `true` | Enable HW encoding |

#### Libraries (`rat.services.jellarr.libraries`)

List of submodules:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Library display name |
| `collectionType` | enum: movies, tvshows, music, homevideos, etc. | Jellyfin collection type |
| `paths` | list of strings | Media paths for this library |

#### Branding (`rat.services.jellarr.branding`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.loginDisclaimer` | null or string | `null` | Login page disclaimer HTML |
| `.customCss` | null or string | `null` | Custom CSS |
| `.splashscreenEnabled` | bool | `false` | Splash screen |

### Internal Mechanism: `_jellarrPlugins`

An internal option (list of attrsets) that plugin sub-modules append to. The base module assembles the final YAML by combining system settings, encoding, libraries, branding, users, startup, and the collected plugins list.

### Service Wiring

- Imports upstream `inputs.jellarr.nixosModules.default`
- Sets `services.jellarr.enable = true`
- Sets `services.jellarr.config` from assembled Nix attrset
- Bootstrap: API key from SOPS (`secrets/jellyfin.yaml`), pointed at `config.services.jellyfin.dataDir`
- `services.jellarr.environmentFile` from SOPS template (for `JELLARR_API_KEY`)
- Impermanence: persist `/var/lib/jellarr`
- Systemd ordering: after `jellyfin.service`

### YAML Assembly

The SOPS template `jellarr.yml` is built as a Nix string interpolation (like configarr) combining:

```yaml
version: 1
base_url: "${config.links.jellyfin.url}"
system:
  enableMetrics: true
  pluginRepositories:
    - name: "Jellyfin Official"
      url: "https://repo.jellyfin.org/releases/plugin/manifest.json"
      enabled: true
    - name: "SSO-Auth"
      url: "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json"
      enabled: true
    - name: "Shokofin"
      url: "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json"
      enabled: true
encoding: ...
library: ...
branding: ...
startup: ...
plugins: ... (from _jellarrPlugins)
```

Plugin repositories are conditionally added based on which plugins are enabled.

## `ldap.nix` — LDAP Auth Plugin

### Options (`rat.services.jellarr.plugins.ldap`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.enable` | bool | `false` | Enable LDAP Auth plugin |
| `.server` | string | `"localhost"` | LDAP server host |
| `.port` | int | `3389` | LDAP port (Authentik outpost) |
| `.useSsl` | bool | `false` | Use SSL (local, no TLS) |
| `.useStartTls` | bool | `false` | Use StartTLS |
| `.baseDn` | string | `"OU=jellyfin,DC=ldap,DC=goauthentik,DC=io"` | Search base DN |
| `.bindUser` | string | `"cn=ldap-search,ou=users,dc=ldap,dc=goauthentik,dc=io"` | Bind DN |
| `.searchFilter` | string | `"(objectClass=user)"` | LDAP search filter |
| `.adminFilter` | string | `""` | Admin filter (admins via SSO roles) |
| `.searchAttributes` | string | `"uid, cn, mail, displayName"` | Attributes to search |
| `.uidAttribute` | string | `"uid"` | UID attribute |
| `.usernameAttribute` | string | `"cn"` | Username attribute |
| `.createUsersFromLdap` | bool | `true` | Auto-create users |
| `.enableAllFolders` | bool | `true` | Grant access to all libraries |

### Secrets

LDAP bind password from SOPS (`secrets/jellyfin.yaml`), key `ldap/bindPassword`, injected via `config.sops.placeholder`.

### Generated Plugin Config

```yaml
- name: "LDAP Authentication"
  configuration:
    LdapServer: "localhost"
    LdapPort: 3389
    UseSsl: false
    UseStartTls: false
    LdapBindUser: "cn=ldap-search,ou=users,dc=ldap,dc=goauthentik,dc=io"
    LdapBindPassword: "<SOPS placeholder>"
    LdapBaseDn: "OU=jellyfin,DC=ldap,DC=goauthentik,DC=io"
    LdapSearchFilter: "(objectClass=user)"
    LdapAdminFilter: ""
    LdapSearchAttributes: "uid, cn, mail, displayName"
    LdapUidAttribute: "uid"
    LdapUsernameAttribute: "cn"
    CreateUsersFromLdap: true
    EnableAllFolders: true
```

## `sso.nix` — SSO/OIDC Plugin

### Options (`rat.services.jellarr.plugins.sso`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.enable` | bool | `false` | Enable SSO plugin |

#### Per-provider (`rat.services.jellarr.plugins.sso.providers.<name>`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.oidEndpoint` | string | — | OIDC discovery endpoint |
| `.oidClientId` | string | — | Client ID (SOPS placeholder) |
| `.oidSecret` | string | — | Client secret (SOPS placeholder) |
| `.enabled` | bool | `true` | Provider enabled |
| `.enableAuthorization` | bool | `true` | Enable authorization |
| `.enableAllFolders` | bool | `true` | Grant all library access |
| `.adminRoles` | list of str | `[]` | Roles granting admin |
| `.roles` | list of str | `[]` | Roles granting access |
| `.defaultUsernameClaim` | null or str | `"preferred_username"` | Username claim |
| `.roleClaim` | null or str | `"groups"` | Role claim |
| `.defaultProvider` | null or str | `null` | Default auth provider for created users |
| `.schemeOverride` | null or str | `"https"` | Scheme override |
| `.doNotValidateEndpoints` | bool | `false` | Skip endpoint validation |
| `.doNotValidateIssuerName` | bool | `false` | Skip issuer validation |
| `.disableHttps` | bool | `false` | Disable HTTPS requirement |
| `.folderRoleMapping` | list of `{ role; folders; }` | `[]` | Role-to-folder mapping |

### Secrets

`oidClientId` and `oidSecret` from SOPS (`secrets/jellyfin.yaml`), keys `sso/clientId` and `sso/clientSecret`.

### Generated Plugin Config

```yaml
- name: "SSO-Auth"
  configuration:
    SamlConfigs: {}
    OidConfigs:
      authentik:
        OidEndpoint: "https://auth.thisratis.gay/application/o/jellyfin/.well-known/openid-configuration"
        OidClientId: "<SOPS placeholder>"
        OidSecret: "<SOPS placeholder>"
        Enabled: true
        EnableAuthorization: true
        EnableAllFolders: true
        DefaultUsernameClaim: "preferred_username"
        RoleClaim: "groups"
        SchemeOverride: "https"
```

## `shokofin.nix` — Shokofin Plugin

### Options (`rat.services.jellarr.plugins.shokofin`)

#### Connection

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.enable` | bool | `false` | Enable Shokofin |
| `.url` | string | `config.links.shoko.url` | Shoko server URL |
| `.username` | string | `"Default"` | Shoko username |

#### Library Structure

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.libraryOperationMode` | enum | `"VFS"` | VFS or Direct |
| `.useGroupsForShows` | bool | `false` | Group shows |
| `.separateMovies` | bool | `false` | Separate movies |
| `.filterMovieLibraries` | bool | `true` | Filter non-movies |
| `.addTrailers` | bool | `true` | Include trailers |
| `.addMissingMetadata` | bool | `true` | Include missing entries |

#### VFS (`rat.services.jellarr.plugins.shokofin.vfs`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.threads` | int | `4` | Concurrent link threads |
| `.addReleaseGroup` | bool | `false` | Add release group to filename |
| `.addResolution` | bool | `false` | Add resolution to filename |
| `.resolveLinks` | bool | `false` | Follow symlinks |

#### Titles

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.titleMainOrder` | list of enum | `["Shoko" "AniDB" "TMDB"]` | Title provider priority |
| `.titleMainList` | list of enum | `["Romaji" "English" "Default"]` | Title language priority |
| `.titleAlternateOrder` | list of enum | `["Shoko" "AniDB" "TMDB"]` | Alternate title providers |
| `.titleAlternateList` | list of enum | `["English" "Romaji" "Japanese" "Default"]` | Alternate title languages |

#### Descriptions

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.descriptionSourceOrder` | list of enum | `["AniDB" "TMDB" "Shoko"]` | Description provider priority |
| `.synopsisEnableMarkdown` | bool | `true` | Markdown formatting |
| `.synopsisCleanLinks` | bool | `true` | Clean links |
| `.synopsisCleanMiscLines` | bool | `true` | Clean misc lines |
| `.synopsisRemoveSummary` | bool | `true` | Remove summaries |

#### Tags & Genres

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.hideUnverifiedTags` | bool | `true` | Hide unverified |
| `.tagMaximumDepth` | int | `0` | Tag depth |
| `.genreMaximumDepth` | int | `1` | Genre depth |
| `.addAniDBId` | bool | `true` | Include AniDB ID |
| `.addTMDBId` | bool | `false` | Include TMDB ID |

#### SignalR

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.signalrAutoConnect` | bool | `true` | Auto-connect |
| `.signalrRefreshEnabled` | bool | `true` | Refresh on changes |
| `.signalrFileEvents` | bool | `true` | File event notifications |

#### Collections

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.autoMergeVersions` | bool | `true` | Merge alternate versions |
| `.autoReconstructCollections` | bool | `true` | Rebuild after scans |
| `.collectionMinSizeOfTwo` | bool | `true` | Min 2 entries |

### Secrets

API key from SOPS (`secrets/jellyfin.yaml`), key `shokofin/apiKey`.

### Generated Plugin Config

```yaml
- name: "Shoko"
  configuration:
    Url: "http://127.0.0.1:8111"
    Username: "Default"
    ApiKey: "<SOPS placeholder>"
    DefaultLibraryOperationMode: "VFS"
    UseGroupsForShows: false
    SeparateMovies: false
    TitleMainList: ["Romaji", "English", "Default"]
    TitleAlternateList: ["English", "Romaji", "Japanese", "Default"]
    DescriptionSourceOrder: ["AniDB", "TMDB", "Shoko"]
    SynopsisEnableMarkdown: true
    SignalR_AutoConnectEnabled: true
    SignalR_RefreshEnabled: true
    SignalR_FileEvents: true
    AutoMergeVersions: true
    ...
```

## Iserlohn Configuration

In `systems/iserlohn/default.nix`:

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
        oidClientId = config.sops.placeholder."jellyfin/sso/clientId";
        oidSecret = config.sops.placeholder."jellyfin/sso/clientSecret";
      };
    };
    shokofin.enable = true;
  };
};
```

## Secrets Required in `secrets/jellyfin.yaml`

```yaml
# Jellarr bootstrap API key (injected into Jellyfin's DB)
jellarr/apiKey: ...

# LDAP bind password (Authentik ldap-search service account)
ldap/bindPassword: ...

# SSO OIDC credentials (from Authentik OAuth2 provider)
sso/clientId: ...
sso/clientSecret: ...

# Shokofin API key (from Shoko Server)
shokofin/apiKey: ...
```

## Plugin Repository Management

Plugin repositories are conditionally added to `system.pluginRepositories` based on which plugins are enabled:
- Jellyfin Official repo is always included
- SSO-Auth repo (`https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json`) added when `plugins.sso.enable = true`
- Shokofin repo (`https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json`) added when `plugins.shokofin.enable = true`
- LDAP Auth is in the official repo, so no additional repository needed

# Jellarr NixOS Module Design

Declarative Jellyfin configuration management via [Jellarr](https://github.com/venkyr77/jellarr), with typed Nix options for LDAP auth, SSO/OIDC, and Shokofin plugins.

## Overview

Jellarr is a TypeScript tool that applies YAML-defined settings to a Jellyfin server via its REST API. The upstream flake provides a package but its NixOS module bakes config into the Nix store via `pkgs.writeText`, making it unsuitable for secrets.

This design builds a **fully custom systemd service** (modeled on the upstream module's behavior) with `rat.services.jellarr.*` options following existing patterns (SOPS templates, `links.*` service discovery, impermanence). Each plugin gets typed Nix options that generate the corresponding Jellarr YAML plugin configuration block. The config YAML is assembled as a `sops.templates` entry with SOPS placeholders for all secrets.

### Why Custom Service Instead of Upstream Module

The upstream module's `services.jellarr.config` is a typed Nix attrset serialized via `pkgs.writeText` — secrets end up in plaintext in `/nix/store`. Rather than fighting the upstream (dummy config + preStart override), we build our own service that:

1. Uses the upstream **package** (`inputs.jellarr.packages.${system}.default`) for the binary
2. Builds the YAML config as a **SOPS template** with secret placeholders (like the configarr pattern)
3. Implements **bootstrap** (API key injection into Jellyfin's SQLite DB) as a separate oneshot service
4. Provides a **health check** (curl wait for Jellyfin) before running
5. Runs on a **systemd timer** (daily, with randomized delay)

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
- `flake.nix` — add `jellarr` flake input (package only, not the NixOS module)

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

Note: defaults are tuned for Pascal-generation NVIDIA GPUs (Quadro P1000 on iserlohn). Override for different hardware.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `.enable` | bool | `true` | Enable encoding config |
| `.hardwareAccelerationType` | enum | `"nvenc"` | HW accel type (none, amf, qsv, nvenc, v4l2m2m, vaapi, videotoolbox, rkmpp) |
| `.hardwareDecodingCodecs` | list of str | `["h264" "hevc" "mpeg2video" "vc1" "vp8" "vp9"]` | Pascal-supported decode codecs |
| `.enableDecodingColorDepth10Hevc` | bool | `true` | 10-bit HEVC decode |
| `.enableDecodingColorDepth10HevcRext` | bool | `true` | 10-bit HEVC RExt decode |
| `.enableDecodingColorDepth12HevcRext` | bool | `false` | 12-bit HEVC RExt decode (Pascal limited) |
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

An internal option (`types.listOf (types.submodule { name = types.str; configuration = types.nullOr types.attrs; })`, default `[]`) that plugin sub-modules append to via list concatenation. The base module collects all entries and renders them into the `plugins:` section of the YAML template.

Similarly, `_jellarrPluginRepos` collects plugin repository entries (submodule with `name`, `url`, `enabled`) conditionally added by each plugin sub-module.

### Service Wiring

**User/group:**
- `users.users.jellarr` — system user, home `/var/lib/jellarr`
- `users.groups.jellarr`
- `systemd.tmpfiles.rules` — ensure `/var/lib/jellarr` exists with correct ownership

**SOPS secrets:**

All secrets sourced from `secrets/jellyfin.yaml` (relative path from module: `../../../../../secrets/jellyfin.yaml`). The `jellarr/*` keys are new additions to this existing file (which already contains `clientId` and `clientSecret` for terraform/authentik — no conflicts since the new keys are under the `jellarr/` namespace).

Declarations — reuses existing secret values where possible, but each module declares its own `sops.secrets` entries (SOPS-nix merges compatible duplicates):

```nix
# default.nix declares:
sops.secrets."jellarr/apiKey" = {
  sopsFile = ../../../../../secrets/jellyfin.yaml;
  key = "jellarr/apiKey";
  owner = "jellarr";
  group = "jellyfin";  # bootstrap service runs as jellyfin, needs read access
  mode = "0440";
};
sops.secrets."jellarr/shokofin/apiKey" = {
  sopsFile = ../../../../../secrets/jellyfin.yaml;
  key = "jellarr/shokofin/apiKey";
  owner = "jellarr";
  mode = "0400";
};

# ldap.nix declares:
sops.secrets."jellarr/ldap/password" = {
  sopsFile = ../../../../../secrets/authentik.yaml;
  key = "ldap/password";
  owner = "jellarr";
  mode = "0400";
};

# sso.nix declares (for each provider):
sops.secrets."jellarr/sso/clientId" = {
  sopsFile = ../../../../../secrets/jellyfin.yaml;
  key = "clientId";           # existing top-level key in jellyfin.yaml
  owner = "jellarr";
  mode = "0400";
};
sops.secrets."jellarr/sso/clientSecret" = {
  sopsFile = ../../../../../secrets/jellyfin.yaml;
  key = "clientSecret";       # existing top-level key in jellyfin.yaml
  owner = "jellarr";
  mode = "0400";
};
```

Templates:
- `sops.templates."jellarr.yml"` — full config YAML with SOPS placeholders, owned by `jellarr:jellarr`, mode `0400`
- `sops.templates."jellarr.env"` — environment file containing `JELLARR_API_KEY=${config.sops.placeholder."jellarr/apiKey"}`

**Bootstrap service (`systemd.services.jellarr-bootstrap`):**
- Type: oneshot, runs before `jellarr.service`
- After: `jellyfin.service`
- User/Group: `jellyfin`/`media` (runs as Jellyfin's user to have write access to its DB)
- Inserts the API key into Jellyfin's SQLite DB (`${config.services.jellyfin.dataDir}/data/jellyfin.db`) using `sqlite3`
- Reads the raw API key value from `config.sops.secrets."jellarr/apiKey".path` (readable by `jellyfin` user via group `jellyfin` + mode `0440`)
- Idempotent: checks if key already exists before inserting
- `pkgs.sqlite` in service `path`

**Main service (`systemd.services.jellarr`):**
- Type: oneshot
- After: `jellyfin.service`, `jellarr-bootstrap.service`, `network-online.target`
- Wants: `jellyfin.service`, `jellarr-bootstrap.service`
- Requires: `network-online.target`
- User/Group: `jellarr`
- WorkingDirectory: `/var/lib/jellarr`
- EnvironmentFile: SOPS template `jellarr.env`
- preStart: health-check Jellyfin via curl (120s timeout, 1s interval) against `config.links.jellyfin.url`, then install config via `install -m 0400 ${config.sops.templates."jellarr.yml".path} /var/lib/jellarr/config/config.yml`
- ExecStart: `${inputs'.jellarr.packages.default}/bin/jellarr`
- `pkgs.curl` in service `path`

**Timer (`systemd.timers.jellarr`):**
- OnCalendar: `daily`
- RandomizedDelaySec: `5m` (avoids thundering herd with other daily timers like configarr)
- Persistent: `true`
- WantedBy: `timers.target`

**Impermanence:** persist `/var/lib/jellarr`

### YAML Assembly

The SOPS template `jellarr.yml` is built as a Nix string interpolation (like configarr). The base module defines a helper that renders the full YAML from the typed options and `_jellarrPlugins`/`_jellarrPluginRepos` internal lists. Example output:

```yaml
version: 1
base_url: "http://127.0.0.1:8096"
system:
  enableMetrics: true
  pluginRepositories:
    - name: "Jellyfin Official"
      url: "https://repo.jellyfin.org/releases/plugin/manifest.json"
      enabled: true
    # conditionally added by plugin sub-modules:
    - name: "SSO-Auth"
      url: "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json"
      enabled: true
    - name: "Shokofin"
      url: "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json"
      enabled: true
  trickplayOptions:
    enableHwAcceleration: true
    enableHwEncoding: true
encoding:
  enableHardwareEncoding: true
  hardwareAccelerationType: "nvenc"
  hardwareDecodingCodecs: ["h264", "hevc", "mpeg2video", "vc1", "vp8", "vp9"]
  enableDecodingColorDepth10Hevc: true
  enableDecodingColorDepth10Vp9: true
  allowHevcEncoding: true
  allowAv1Encoding: false
library:
  virtualFolders:
    - name: "Movies"
      collectionType: "movies"
      libraryOptions:
        pathInfos:
          - path: "/mnt/media/movies"
    # ... etc
branding:
  splashscreenEnabled: false
startup:
  completeStartupWizard: true
plugins:
  - name: "LDAP Authentication"
    configuration:
      LdapBindPassword: "<SOPS placeholder>"
      # ...
  - name: "SSO-Auth"
    configuration:
      OidConfigs:
        authentik:
          OidSecret: "<SOPS placeholder>"
          # ...
  - name: "Shoko"
    configuration:
      ApiKey: "<SOPS placeholder>"
      # ...
```

The `library.virtualFolders[].libraryOptions.pathInfos` structure matches Jellarr's expected format — the `rat.services.jellarr.libraries[].paths` option (list of strings) is transformed to `pathInfos = map (p: { path = p; })` during YAML assembly.

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

LDAP bind password reuses the existing `ldap/password` value from `secrets/authentik.yaml`, declared as `sops.secrets."jellarr/ldap/password"` by this module. Injected via `config.sops.placeholder."jellarr/ldap/password"` into the YAML template.

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

`oidClientId` and `oidSecret` are not exposed as options — they reuse the existing `clientId` and `clientSecret` values from `secrets/jellyfin.yaml` (already used by terraform for the Jellyfin OAuth2 provider). The SSO module declares `sops.secrets."jellarr/sso/clientId"` and `sops.secrets."jellarr/sso/clientSecret"` (with `key` mapping to the existing top-level keys in the file), injected via `config.sops.placeholder."jellarr/sso/clientId"` and `config.sops.placeholder."jellarr/sso/clientSecret"` into the YAML template.

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

API key from SOPS (`secrets/jellyfin.yaml`), key `jellarr/shokofin/apiKey`.

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
        # oidClientId and oidSecret auto-sourced from SOPS (secrets/jellyfin.yaml keys: clientId, clientSecret)
      };
    };
    shokofin.enable = true;
  };
};
```

## Secrets

### New keys to add to `secrets/jellyfin.yaml`

```yaml
# Jellarr API key (used for both bootstrap DB injection and runtime auth)
jellarr/apiKey: ...

# Shokofin API key (from Shoko Server)
jellarr/shokofin/apiKey: ...
```

### Existing secret values reused (no new keys needed in these files)

| Secret | File | Key in file | SOPS-nix name | Used by |
|--------|------|-------------|---------------|---------|
| SSO client ID | `secrets/jellyfin.yaml` | `clientId` | `jellarr/sso/clientId` | Terraform + Jellarr SSO plugin |
| SSO client secret | `secrets/jellyfin.yaml` | `clientSecret` | `jellarr/sso/clientSecret` | Terraform + Jellarr SSO plugin |
| LDAP bind password | `secrets/authentik.yaml` | `ldap/password` | `jellarr/ldap/password` | Authentik LDAP outpost + Jellarr LDAP plugin |

## Plugin Repository Management

Plugin repositories are conditionally added to `system.pluginRepositories` based on which plugins are enabled:
- Jellyfin Official repo is always included
- SSO-Auth repo (`https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json`) added when `plugins.sso.enable = true`
- Shokofin repo (`https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json`) added when `plugins.shokofin.enable = true`
- LDAP Auth is in the official repo, so no additional repository needed

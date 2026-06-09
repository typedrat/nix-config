# Sunshine Game Streaming on Ulysses — Design

**Date:** 2026-06-08
**Host:** ulysses (Ryzen 9 9950X3D, 128GB DDR5, RTX 5090, Hyprland/Wayland)
**Status:** Approved — ready for implementation planning

## Goal

Set up [Sunshine](https://github.com/LizardByte/Sunshine) as a LAN game-streaming
host on Ulysses, targeting two Moonlight clients:

- **iPad** (Moonlight iOS) — up to 1440p/4K, 60–120fps
- **Switch** (Moonlight homebrew) — capped at 1080p/60, bandwidth-sensitive

Streaming must use an **on-demand virtual display** so the physical monitors
(DP-1 4K@120, HDMI TV) are untouched while streaming. Hardware encoding via
NVENC on the RTX 5090.

## Non-Goals (YAGNI)

- Remote/internet streaming (no port forwarding, Tailscale, etc.) — LAN only.
- A dedicated streaming user / true concurrent independent Steam sessions
  (see "Steam single-instance" below — explicitly chosen against).
- Per-user home-manager module — system-level toggle only.

## Approach Summary

1. New NixOS module `modules/nixos/games/sunshine.nix` following the existing
   `steam.nix` pattern, gated on `rat.gaming.enable`, exposing
   `rat.gaming.sunshine.{enable, users, openFirewall}`.
2. Enable upstream `services.sunshine` (already in locked nixpkgs) with
   `capSysAdmin = true`, `autoStart = true`, declarative `settings` +
   `applications`.
3. Patch in nixpkgs PR #521906 for the current, security-patched Sunshine
   package (locked nixpkgs ships a ~1yr-stale version with known CVEs).
4. On-demand Hyprland headless virtual display via a committed
   `writeShellApplication` script, driven by Sunshine app `prep-cmd` do/undo
   hooks. **Not evdi** — see rationale. evdi documented as Plan B fallback.
5. Rely on already-enabled avahi/mDNS for discovery; PIN pairing via web UI.
6. Pre-seed the web-UI admin credentials declaratively via SOPS (hashed
   credential JSON), pointing Sunshine's `credentials_file` at the
   group-readable `/run/secrets` path — no first-run web-UI credential step.

## Module Structure

New file `modules/nixos/games/sunshine.nix`, imported from
`modules/nixos/games/default.nix`.

```nix
options.rat.gaming.sunshine = {
  enable = mkEnableOption "Sunshine game streaming host";

  users = mkOption {
    type = types.listOf types.str;
    default = [];
    example = [ "awilliams" ];
    description = ''
      Users permitted to use Sunshine. Each listed user is added to the
      `uinput` group (so Moonlight clients can inject gamepad, keyboard, and
      mouse input via /dev/uinput) and the `sunshine` group (so they can read
      the credentials_file).
    '';
  };

  openFirewall = mkOption {
    type = types.bool;
    default = true;
    description = "Open the LAN firewall ports Sunshine/Moonlight require.";
  };
};

config = mkIf (config.rat.gaming.enable && cfg.enable) {
  # Dedicated group for credential-file access (distinct from uinput, even
  # though the user set overlaps today — credential access != input access).
  users.groups.sunshine = {};

  # Grant each permitted user uinput access (input injection) and sunshine
  # group membership (credentials_file read).
  users.users = lib.genAttrs cfg.users (_: {
    extraGroups = [ "uinput" "sunshine" ];
  });

  # SOPS-decrypted hashed credential JSON, group-readable, in /run (tmpfs).
  sops.secrets."sunshine/credentials" = {
    mode = "0440";
    group = "sunshine";
    # path defaults to /run/secrets/sunshine/credentials
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;     # required for KMS/DRM screen capture on Wayland
    openFirewall = cfg.openFirewall;
    settings = {
      sunshine_name = "ulysses";
      encoder = "nvenc";
      credentials_file = config.sops.secrets."sunshine/credentials".path;
    };
    applications = { /* see Applications */ };
  };

  # Non-fatal guard: Sunshine still streams video without input injection,
  # but Moonlight gamepad/keyboard/mouse will silently fail.
  warnings = lib.optional (cfg.users == []) ''
    rat.gaming.sunshine is enabled but `users` is empty. No user has been
    added to the `uinput`/`sunshine` groups, so Moonlight input injection
    and credential-file access will not work.
    Set `rat.gaming.sunshine.users = [ "<username>" ];`.
  '';
};
```

### Key decisions

- **`openFirewall` defaults to `true`** (unlike most repo modules which default
  `false`) because this module's sole purpose is LAN streaming and it is only
  ever enabled explicitly per-host. Upstream opens the correct Moonlight port
  set offset from base port `47989`: TCP `{base-5, base, base+1, base+21}`,
  UDP `{base+9, base+10, base+11, base+13, base+21}`.
- **`users` is a list**, not a bool — explicit about who gets input-injection
  rights. The upstream module already sets `hardware.uinput.enable = true`
  (creating the `uinput` group + udev rule) and installs Sunshine's udev rules
  via `services.udev.packages`; we add `uinput` membership plus a dedicated
  `sunshine` group for credential-file access.
- **Dedicated `sunshine` group for credentials**, not user-owned and not
  reusing `uinput`. A list-of-users has no single owner, so the credential
  file is group-readable (`0440`, group `sunshine`). The group is distinct
  from `uinput` because credential access and input access are different
  concerns even if the user set overlaps today. This also removes any need
  for a "primary user" / `credentialsUser` option.
- **Empty-users guard is a warning, not an assertion** — Sunshine remains
  usable for video; a hard build failure would be overkill.
- **System-level only** — the upstream module runs Sunshine as a
  `systemd.user.service` bound to `graphical-session.target`, so it runs inside
  the Hyprland session where it can reach Wayland. No home-manager module.

## nixpkgs Patch (PR #521906)

The Sunshine package in locked nixpkgs (rev `331800d...`) is the stale
`2025.924.154138` with unfixed security vulnerabilities (labeled
`1.severity: security` upstream). PR #521906 bumps it to `2026.516.143833`.

It is a **package** rework (upstream refactored their build: prebuilt ffmpeg
fetch, boost 1.89 pin, renamed systemd unit, new build deps), not a simple
version bump. Approved by 3+ reviewers including the package maintainer; builds
pass on `x86_64-linux`.

Add to `flake.nix` under `#region nixpkgs patches`:

```nix
# sunshine: 2025.924.154138 -> 2026.516.143833, a ~1yr-stale version with
# unfixed security vulnerabilities. Upstream refactored their build (prebuilt
# ffmpeg fetch, boost 1.89, renamed systemd unit), so this is a package
# rework, not a simple version bump. (NixOS/nixpkgs#521906)
nixpkgs-patch-521906 = {
  url = "https://github.com/NixOS/nixpkgs/pull/521906.diff";
  flake = false;
};
```

The `patcher.nix` module auto-discovers `nixpkgs-patch-*` inputs — no other
wiring needed.

### Verification risk (implementation-time, not a design change)

The PR renames the upstream systemd unit file
(`sunshine.service.in` → `app-dev.lizardbyte.app.Sunshine.service.in`) and
changes executable-path injection. However, the **NixOS module** builds its own
`systemd.user.services.sunshine` unit and calls `getExe cfg.package` (wrapped
via `security.wrappers` when `capSysAdmin`) — it does **not** consume the
upstream `.service.in`. So the module should remain compatible. **Verify** by
building `nixosConfigurations.ulysses` and confirming the user unit resolves
against the new package.

## Settings (fully declarative)

```nix
services.sunshine.settings = {
  sunshine_name = "ulysses";
  encoder = "nvenc";   # pin NVENC for reproducibility (RTX 5090)
  credentials_file = config.sops.secrets."sunshine/credentials".path;
};
```

**Trade-off (documented, accepted):** Once `settings`/`applications` are set in
Nix, those become Nix-managed and read-only in the web UI (per upstream module).
Pairing still works via the web UI. Changing the app list or settings means a
rebuild, not a UI click. This matches the repo's declarative philosophy and is
the intended trade.

## Applications

Two declarative apps. Both share the on-demand virtual-display lifecycle via
`prep-cmd`. The virtual-display logic lives in a committed
`pkgs.writeShellApplication` (`sunshine-virtual-display`) because the headless
output name (`HEADLESS-N`) is not known until after creation — inline `hyprctl`
one-liners are too fragile.

```nix
services.sunshine.applications = {
  env.PATH = "$(PATH):${pkgs.hyprland}/bin";
  apps = [
    {
      name = "Steam Big Picture";
      prep-cmd = [{
        do   = "${sunshineVirtualDisplay}/bin/sunshine-virtual-display create-steam";
        undo = "${sunshineVirtualDisplay}/bin/sunshine-virtual-display destroy-steam";
      }];
      auto-detach = "true";
      exclude-global-prep-cmd = "false";
      image-path = "steam.png";
    }
    {
      name = "Desktop (Virtual Display)";
      prep-cmd = [{
        do   = "${sunshineVirtualDisplay}/bin/sunshine-virtual-display create";
        undo = "${sunshineVirtualDisplay}/bin/sunshine-virtual-display destroy";
      }];
      auto-detach = "true";
      exclude-global-prep-cmd = "false";
    }
  ];
};
```

### Virtual-display script behavior

On `create` (and `create-steam`):
1. `hyprctl output create headless` → discover the new `HEADLESS-N` name.
2. Read `SUNSHINE_CLIENT_WIDTH` / `SUNSHINE_CLIENT_HEIGHT` / `SUNSHINE_CLIENT_FPS`
   (set by Sunshine to the client's request). Size the headless output to match.
   Fallback: `1920x1080@60` if unset.
3. Move a dedicated streaming workspace onto `HEADLESS-N`.
4. (`create-steam` only) Signal the **existing** Steam into Big Picture:
   `steam steam://open/bigpicture`.

On `destroy` (and `destroy-steam`):
1. (`destroy-steam` only) Exit Big Picture: `steam steam://close/bigpicture`.
2. Move the streaming workspace back to a physical output.
3. `hyprctl output remove HEADLESS-N`.

### Steam single-instance behavior (Option B — chosen)

Steam is single-instance per user. `steam -gamepadui`/`steam://open/bigpicture`
does **not** start a second Steam — it switches the **existing** desktop Steam
into Big Picture. Therefore:

- We use the **one shared Steam instance**, switched to Big Picture on the
  virtual display for streaming, and switched back on disconnect (we do **not**
  quit Steam — it is the user's only instance).
- **Consequence (accepted):** streaming and desk-gaming are mutually exclusive
  (same Steam process). Fine for couch streaming — you are not gaming at the
  desk and streaming simultaneously.
- The "Desktop (Virtual Display)" app remains as a fallback for non-Steam
  access (settings, anime-game-launchers, etc.).

A dedicated streaming user (true concurrent independent Steam) was explicitly
considered and rejected for complexity — see Alternatives.

## Why Hyprland Headless, Not evdi

- **Hyprland provides virtual outputs natively** via the wlroots headless
  backend (`hyprctl output create headless`) — userspace, no kernel module,
  clean on-demand create/destroy. This is the mechanism the design relies on.
- **evdi + NVIDIA proprietary is historically fragile** and would add an
  out-of-tree DRM module to a carefully blacklisted NVIDIA setup for no gain.
- **evdi tends to be always-on/imperative**, contradicting the on-demand,
  declarative goals.
- **evdi does not solve Steam single-instance** — it provides a second display,
  not a second session.

**Plan B (documented escape hatch):** If `hyprctl output create headless`
misbehaves on NVIDIA + wlroots at implementation/test time, fall back to evdi
via `virtual-display-linux`. Recorded here so we don't rediscover it.

## Wiring

- Create `modules/nixos/games/sunshine.nix`.
- Add `./sunshine.nix` to imports in `modules/nixos/games/default.nix`.
- In `systems/ulysses/default.nix`, extend the existing `rat.gaming` block:

```nix
gaming = {
  enable = true;
  animeGameLaunchers.enable = true;
  steam.enable = true;
  sunshine = {
    enable = true;
    users = [ "awilliams" ];
    # openFirewall defaults to true
  };
};
```

- Existing Hyprland `monitors`/`workspaces` config is unaffected; the script
  manages a dedicated streaming workspace on the transient headless output.

## Secrets (SOPS)

Sunshine's web-UI admin credentials are stored in a JSON file containing the
username and a **salted password hash** (never plaintext). Sunshine reads it via
the `credentials_file` setting (default `sunshine_state.json`). We pre-seed this
declaratively rather than using the first-run web-UI step.

**Design:**

- Store the hashed credential JSON as a SOPS secret in `secrets/sunshine.yaml`,
  encrypted to the `host_ulysses` age key (per existing `.sops.yaml` rules).
- Decrypt to the default SOPS path under `/run/secrets` (tmpfs) — **not** the
  home dir. This is correct for Ulysses' impermanence setup (home is ephemeral)
  and is where SOPS-nix decrypts natively.
- **Group-readable** (`mode = "0440"`, `group = "sunshine"`) so any user in
  `rat.gaming.sunshine.users` (all of whom are in the `sunshine` group) can read
  it. No single owner needed.
- Point `services.sunshine.settings.credentials_file` at
  `config.sops.secrets."sunshine/credentials".path`.

```nix
sops.secrets."sunshine/credentials" = {
  mode = "0440";
  group = "sunshine";
  # path defaults to /run/secrets/sunshine/credentials
};
```

**One-time bootstrap (manual, documented):**

The hashed credential JSON must be generated once with a password you choose,
then encrypted into the repo:

1. Run locally: `sunshine --creds <username> <password>` — this writes the
   hashed-credential JSON (the salted hash, not the plaintext).
2. Take the resulting JSON (Sunshine's `sunshine_state.json` /
   credentials file content) and add it to `secrets/sunshine.yaml` under the
   `sunshine/credentials` key, encrypted via `sops`.
3. The module consumes it on next rebuild; no web-UI credential step needed.

Moonlight client pairing remains PIN-based at connect time (not a stored
secret) — only the admin web-UI credentials are pre-seeded.

## Testing Plan

1. `nix flake check` — patch applies, config evaluates.
2. `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel` —
   patched package builds; systemd user unit resolves against new package
   (the unit-rename verification from the patch section).
3. `nix run .#boot` (safe) then `nix run .#switch`.
4. `systemctl --user status sunshine` running in the Hyprland session.
5. `id awilliams` includes both `uinput` and `sunshine`.
6. SOPS secret decrypts: `/run/secrets/sunshine/credentials` exists, is
   `0440 root:sunshine`, and Sunshine loads it (web UI at
   `https://localhost:47990` accepts the pre-seeded credentials without a
   first-run setup prompt).
7. Pair iPad Moonlight via PIN; launch "Steam Big Picture"; confirm headless
   output created, Big Picture appears on it (not on DP-1), input injection
   works; disconnect returns Steam and removes the output.
8. Repeat with Switch Moonlight client.

## Alternatives Considered

- **Stream desktop as-is / dynamic mode switching on a physical monitor** —
  rejected; disrupts the real desktop. Virtual display chosen.
- **Always-on virtual display** — rejected for on-demand (cleaner idle state).
- **evdi virtual display** — rejected; native Hyprland headless supersedes it.
  Retained as Plan B fallback only.
- **Dedicated `stream` user (Option A)** — true concurrent independent Steam,
  but separate Steam login/library, more complex Sunshine session targeting.
  Rejected for complexity; couch-streaming rarely needs desk-gaming concurrency.
- **gamescope nested session** — helps display placement but not Steam
  single-instance; doesn't deliver concurrency without a separate user.
- **Web-UI first-run credentials (no SOPS)** — considered, rejected: less
  declarative, and imperative first-run state is awkward under impermanence.
  SOPS-seeded hashed credentials chosen instead.
- **User-owned / home-dir credentials_file** — rejected: a list-of-users has
  no single owner, and the home dir is ephemeral under impermanence. Group-
  readable secret in `/run/secrets` chosen instead.

# Nintendo Switch RCM Auto-Payload — Design

**Date:** 2026-06-09
**Host:** ulysses (enabled there; module is generic)
**Status:** Approved, pending spec review

## Goal

When a Nintendo Switch is plugged into ulysses in RCM mode, automatically inject
the hekate payload over USB via `fusee-nano`, and broadcast a desktop
notification reporting success or failure. No manual command, no GUI.

## Background / Constraints

- **fusee-nano** is already in nixpkgs as `pkgs.fusee-nano` (pname
  `fusee-nano-unstable`, rev `2979d34`). Binary: `fusee-nano`. Zero runtime
  dependencies (raw kernel USB API, `intermezzo` bundled into the binary — no
  libusb needed). Invocation: `fusee-nano <payload.bin>`. Requires root for
  USB device access.
- **hekate** is NOT in nixpkgs. Its release ships a bare
  `hekate_ctcaer_<ver>.bin` asset directly (no zip needed). We pin v6.5.2,
  standard variant (`hekate_ctcaer_6.5.2.bin`, the 4GB build correct for all
  retail Switches — the `__ram8GB.bin` variant is for rare modded units only).
- **Hardware applicability:** Only vulnerable Erista units expose USB
  `0955:7321` in RCM mode. Mariko / Lite / OLED / patched Erista never present
  this device, so the udev rule simply never matches on them — the module is
  safe to enable unconditionally; it only acts on a compatible console.
- **hekate version is decoupled from SD-card state.** hekate is the
  RCM-injected bootloader, re-sent fresh each boot; latest is always correct.
  Atmosphère/firmware currency lives on the SD card and is updated separately,
  out of scope for this module.
- **Notification daemon:** ulysses runs **mako** under Hyprland
  (`modules/home-manager/desktop/hyprland/notifications/mako.nix`), so
  `notify-send` against a user's session bus displays correctly.
- **Trigger is plug-in only** (udev). No boot-time oneshot.

## Components

### 1. hekate payload package — `packages/hekate-payload.nix`

- `stdenvNoCC.mkDerivation` + `fetchurl` for the pinned
  `hekate_ctcaer_6.5.2.bin` release asset from `CTCaer/hekate`.
- Installs to a **version-independent** path:
  `$out/share/hekate/hekate_ctcaer.bin`, so the consuming module needs no edits
  when the version bumps.
- `passthru.updateScript = nix-update-script { ... }` per repo convention
  (matches `packages/qui-bin.nix`).
- `meta.sourceProvenance = [ binaryNativeCode ]` (prebuilt binary).
- Auto-discovered by the `local-packages` flake-parts module → `pkgs.hekate-payload`.

### 2. NixOS module — `modules/nixos/hardware/nintendo-switch.nix`

Added to `modules/nixos/hardware/default.nix` imports. Filename mirrors the
`nintendoSwitch` option namespace for discoverability.

House style: matches `usbmuxd.nix` / `security-key.nix` (`config`, `lib`,
`pkgs`, `...`; `cfg` binding; `mkIf cfg.enable`).

**Options** under `options.rat.hardware.nintendoSwitch.rcm`:

- `enable` — `mkEnableOption "automatic hekate RCM payload injection for
  Nintendo Switch"`. Off by default.
- `payload` — `mkOption { type = types.path; default =
  "${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin"; }`. Overridable.
- `notify` — `mkOption { type = types.bool; default = true; }`. Broadcast a
  desktop notification on completion.

**Config** (`mkIf cfg.enable`):

- `environment.systemPackages = [ pkgs.fusee-nano ];`
- **udev rule** (`services.udev.extraRules`) matching the RCM device and
  starting the injection service:
  ```
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0955", ATTR{idProduct}=="7321", TAG+="systemd", ENV{SYSTEMD_WANTS}="switch-rcm-inject.service"
  ```
- **`systemd.services.switch-rcm-inject`** — `Type = "oneshot"`:
  - `description = "Inject hekate RCM payload into Nintendo Switch";`
  - `ExecStart = "${lib.getExe pkgs.fusee-nano} ${cfg.payload}";`
  - Runs as root (default), giving USB access. oneshot + systemd lifecycle
    avoids udev's process reaper killing a multi-second injection.
  - On success, `ExecStartPost` invokes the broadcast wrapper with a success
    message (only when `cfg.notify`).
  - `onFailure = [ "switch-rcm-notify-fail.service" ];` (only when `cfg.notify`).
- **`systemd.services.switch-rcm-notify-fail`** (only when `cfg.notify`) —
  `Type = "oneshot"`, invokes the broadcast wrapper with a failure message.
  Decoupling success (`ExecStartPost`) from failure (`OnFailure`) is the clean
  way to pass outcome detail through a systemd oneshot.

### 3. Notification broadcast wrapper — `pkgs.writeShellApplication`

Defined inline in the module (`let broadcast = pkgs.writeShellApplication { ... }`).

- Takes the notification summary/body as arguments (and an urgency, e.g.
  `normal` for success, `critical` for failure).
- Enumerates graphical sessions: `loginctl list-sessions --no-legend`, then for
  each session resolves `Type` (keep `wayland`/`x11`) and `State` (keep
  `active`) and the owning `Uid` via `loginctl show-session`.
- For each qualifying session, runs `notify-send` **as that user** with
  `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus` so mako receives it.
  Uses `runuser -u <user>` (or `sudo -u`) with the env set.
- `runtimeInputs = [ pkgs.systemd pkgs.libnotify pkgs.coreutils ]`.
- No active graphical session → loop is a no-op; journal still records the
  service result. Headless-safe.

### 4. Enablement — `systems/ulysses/default.nix`

```nix
rat.hardware.nintendoSwitch.rcm.enable = true;
```

(`payload` and `notify` left at defaults.)

## Data Flow

```
Switch plugged in (RCM mode, Erista, unpatched)
  -> kernel enumerates USB 0955:7321
  -> udev rule matches: TAG+="systemd", SYSTEMD_WANTS=switch-rcm-inject.service
  -> systemd starts switch-rcm-inject.service (oneshot, root)
  -> fusee-nano sends hekate_ctcaer.bin over USB
       success -> ExecStartPost runs broadcast (normal urgency: "hekate sent")
       failure -> OnFailure -> switch-rcm-notify-fail.service runs broadcast
                  (critical urgency: "injection failed")
  -> broadcast wrapper notify-sends to each active graphical session (mako shows it)
  -> Switch boots into hekate menu
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| fusee-nano nonzero exit | Service fails -> journal records -> `OnFailure` fires failure notification. |
| No Switch / not in RCM / incompatible (Mariko/Lite/OLED/patched) | udev rule never matches; nothing runs. |
| No active graphical session | Broadcast loop no-op; journal still has the service result. |
| Multiple graphical sessions | Each active wayland/x11 session gets the notification. |
| `notify = false` | No `ExecStartPost`/`OnFailure`; journal-only. |

## YAGNI — Deliberately Excluded

- No boot-time oneshot (plug-in trigger only).
- No multi-payload selection / payload-picker UI.
- No sops/secrets (hekate payload is public; nothing sensitive).
- No `RUN+=`-direct-exec variant (fragile under udev's restricted env/reaper).

## Files Touched

- **New:** `packages/hekate-payload.nix`
- **New:** `modules/nixos/hardware/nintendo-switch.nix`
- **Edit:** `modules/nixos/hardware/default.nix` (add import)
- **Edit:** `systems/ulysses/default.nix` (enable)

## Verification

- `nix build .#hekate-payload` — package builds, `.bin` lands at expected path.
- `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel` — config
  evaluates and builds.
- `nix fmt` clean.
- Manual: plug Switch in RCM mode -> `journalctl -u switch-rcm-inject` shows
  fusee-nano output; mako notification appears; Switch boots hekate.
- `passthru.updateScript` validated by the flake's updateScript check.

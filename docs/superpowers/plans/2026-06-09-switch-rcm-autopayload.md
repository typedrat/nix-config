# Nintendo Switch RCM Auto-Payload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a Nintendo Switch is plugged into ulysses in RCM mode, automatically inject the pinned hekate payload over USB via `fusee-nano` and broadcast a desktop notification reporting success or failure.

**Architecture:** A custom `pkgs.hekate-payload` package fetches the pinned `hekate_ctcaer_6.5.2.bin`. A generic NixOS module (`rat.hardware.nintendoSwitch.rcm`) installs a udev rule that tags the RCM USB device (`0955:7321`) and starts a oneshot systemd service running `fusee-nano`. Success/failure each trigger a broadcast wrapper that `notify-send`s to every active graphical session (mako under Hyprland). Enabled on ulysses.

**Tech Stack:** Nix, NixOS modules (`rat.*` namespace), systemd (oneshot + udev TAG integration), `pkgs.fusee-nano`, `pkgs.writeShellApplication`, `loginctl`, `notify-send`.

---

## Context for the Implementer

This is a NixOS configuration flake using `flake-parts`. Key conventions you must follow:

- **Custom packages** live in `packages/` and are auto-discovered via `packagesFromDirectoryRecursive` (pkgs-by-name convention). A file `packages/hekate-payload.nix` becomes `pkgs.hekate-payload` (the overlay merges it into the global nixpkgs set, so it is available inside NixOS modules too). Package functions receive `callPackage`-style args (`lib`, `stdenvNoCC`, `fetchurl`, `nix-update-script`, etc.) — see `packages/qui-bin.nix` for the exact pattern.
- **Every custom package MUST set `passthru.updateScript`** (a flake check enforces this). Use `nix-update-script`.
- **NixOS modules** use the `rat.*` namespace. The house style (see `modules/nixos/hardware/usbmuxd.nix`) is:
  ```nix
  {config, lib, pkgs, ...}: let
    inherit (lib.options) mkEnableOption mkOption;
    inherit (lib.modules) mkIf;
    inherit (lib) types;
    cfg = config.rat.hardware.nintendoSwitch.rcm;
  in {
    options.rat.hardware.nintendoSwitch.rcm = { ... };
    config = mkIf cfg.enable { ... };
  }
  ```
- **`nix fmt`** must be clean before any commit (alejandra/deadnix/statix via treefmt). Run it before committing each task.
- **Building the ulysses config locally may be slow.** You can offload to the server: `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel`. If evaluation-only checks are enough for a step, prefer `nix eval`.
- The hekate `.bin` release asset SRI hash (pinned at v6.5.2) is:
  `sha256-JlSvb5v7jmWit5OGbNj1DRcuQv9GE8GL/YOFAhupbuQ=`

There is no automated test runner for this kind of system glue; verification is `nix build` / `nix eval` and `nix fmt`. There are no unit tests to write, so this plan is build-verification-driven rather than TDD.

---

## File Structure

- **Create** `packages/hekate-payload.nix` — fetches + installs the pinned hekate payload binary.
- **Create** `modules/nixos/hardware/nintendo-switch.nix` — the `rat.hardware.nintendoSwitch.rcm` module (options, udev rule, services, broadcast wrapper).
- **Modify** `modules/nixos/hardware/default.nix` — add the new module to `imports`.
- **Modify** `systems/ulysses/default.nix` — enable `rat.hardware.nintendoSwitch.rcm`.

---

## Task 1: hekate payload package

**Files:**
- Create: `packages/hekate-payload.nix`

- [ ] **Step 1: Write the package**

Create `packages/hekate-payload.nix`:

```nix
{
  lib,
  stdenvNoCC,
  fetchurl,
  nix-update-script,
}: let
  version = "6.5.2";
in
  stdenvNoCC.mkDerivation {
    pname = "hekate-payload";
    inherit version;

    src = fetchurl {
      url = "https://github.com/CTCaer/hekate/releases/download/v${version}/hekate_ctcaer_${version}.bin";
      hash = "sha256-JlSvb5v7jmWit5OGbNj1DRcuQv9GE8GL/YOFAhupbuQ=";
    };

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm644 $src $out/share/hekate/hekate_ctcaer.bin

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "hekate (CTCaer) RCM bootloader payload for Nintendo Switch";
      homepage = "https://github.com/CTCaer/hekate";
      changelog = "https://github.com/CTCaer/hekate/releases/tag/v${version}";
      license = lib.licenses.gpl2Only;
      sourceProvenance = with lib.sourceTypes; [binaryFirmware];
      platforms = lib.platforms.all;
    };
  }
```

Notes:
- `fetchurl` with `dontUnpack = true` because the source is a single `.bin`, not an archive.
- Installs to the **version-independent** path `$out/share/hekate/hekate_ctcaer.bin` so the consuming module never needs editing on a version bump.
- `binaryFirmware` is the correct `sourceProvenance` for a prebuilt bootloader blob.

- [ ] **Step 2: Format**

Run: `nix fmt packages/hekate-payload.nix`
Expected: file reformatted in place (or already clean), exit 0.

- [ ] **Step 3: Build the package**

Run: `nix build .#hekate-payload`
Expected: builds successfully, produces `./result`.

- [ ] **Step 4: Verify the payload lands at the expected path**

Run: `test -f result/share/hekate/hekate_ctcaer.bin && echo OK`
Expected: prints `OK`. (Optionally `ls -l result/share/hekate/hekate_ctcaer.bin` — file should be a few hundred KB.)

- [ ] **Step 5: Verify the updateScript check passes**

Run: `nix build .#checks.x86_64-linux.package-update-scripts 2>/dev/null || nix flake check --no-build 2>&1 | tail -20`
Expected: no failure referencing `hekate-payload` missing an updateScript. (The repo has a flake check validating `passthru.updateScript`; if its exact attr name differs, `nix flake check` surfaces any violation.)

- [ ] **Step 6: Commit**

```bash
git add packages/hekate-payload.nix
git commit -m "feat(packages): add hekate-payload (pinned hekate_ctcaer 6.5.2)"
```

---

## Task 2: NixOS module — options + fusee-nano + udev rule

This task creates the module with the option definitions, the `fusee-nano` package install, and the udev rule. The systemd services and notification wrapper are added in Task 3 (kept separate so each task builds and is reviewable). The module is NOT yet imported (Task 4), so it has no effect on any host until then — but it must still evaluate.

**Files:**
- Create: `modules/nixos/hardware/nintendo-switch.nix`

- [ ] **Step 1: Write the module skeleton (options + udev + package)**

Create `modules/nixos/hardware/nintendo-switch.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types;

  cfg = config.rat.hardware.nintendoSwitch.rcm;
in {
  options.rat.hardware.nintendoSwitch.rcm = {
    enable = mkEnableOption "automatic hekate RCM payload injection for Nintendo Switch";

    payload = mkOption {
      type = types.path;
      default = "${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin";
      defaultText = lib.literalExpression ''"''${pkgs.hekate-payload}/share/hekate/hekate_ctcaer.bin"'';
      description = "Path to the RCM payload (.bin) sent when a Switch is detected in RCM mode.";
    };

    notify = mkOption {
      type = types.bool;
      default = true;
      description = "Broadcast a desktop notification to active graphical sessions on injection success/failure.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.fusee-nano];

    # Tag the Switch RCM device (APX mode, 0955:7321) and have systemd start
    # the injection service when it appears.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0955", ATTR{idProduct}=="7321", TAG+="systemd", ENV{SYSTEMD_WANTS}="switch-rcm-inject.service"
    '';
  };
}
```

- [ ] **Step 2: Format**

Run: `nix fmt modules/nixos/hardware/nintendo-switch.nix`
Expected: reformatted/clean, exit 0.

- [ ] **Step 3: Verify it evaluates standalone**

Because the module is not yet imported, verify it parses and its options typecheck by evaluating it in isolation:

Run:
```bash
nix eval --impure --expr '
  let
    pkgs = import <nixpkgs> {};
    m = import ./modules/nixos/hardware/nintendo-switch.nix {
      config = { rat.hardware.nintendoSwitch.rcm.enable = false; };
      inherit (pkgs) lib;
      inherit pkgs;
    };
  in builtins.attrNames m.options.rat.hardware.nintendoSwitch.rcm
'
```
Expected: `[ "enable" "notify" "payload" ]` (order may vary). This confirms the file parses and option names are correct. (Using `<nixpkgs>` is fine here — we are only checking that the expression evaluates; `pkgs.hekate-payload` is referenced lazily inside the `default`, so it is not forced by this check.)

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/hardware/nintendo-switch.nix
git commit -m "feat(hardware): add nintendoSwitch.rcm module (options, udev rule)"
```

---

## Task 3: NixOS module — injection service + notification broadcast

Adds the systemd oneshot injection service, the notification broadcast wrapper, and the success/failure notification wiring to the module from Task 2.

**Files:**
- Modify: `modules/nixos/hardware/nintendo-switch.nix`

- [ ] **Step 1: Add the broadcast wrapper in the `let` block**

In `modules/nixos/hardware/nintendo-switch.nix`, extend the top `let` block (after the `cfg = ...;` line, before `in`) to define a notification broadcast script. Replace:

```nix
  cfg = config.rat.hardware.nintendoSwitch.rcm;
in {
```

with:

```nix
  cfg = config.rat.hardware.nintendoSwitch.rcm;

  # Broadcasts a notification to every active wayland/x11 session.
  # Usage: switch-rcm-notify <urgency> <summary> <body>
  notifyBroadcast = pkgs.writeShellApplication {
    name = "switch-rcm-notify";
    runtimeInputs = [pkgs.systemd pkgs.libnotify pkgs.coreutils pkgs.gawk pkgs.util-linux];
    text = ''
      urgency="$1"
      summary="$2"
      body="$3"

      # Enumerate session IDs, keep graphical + active ones, notify each user.
      loginctl list-sessions --no-legend | awk '{print $1}' | while read -r sid; do
        [ -n "$sid" ] || continue
        stype="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
        sstate="$(loginctl show-session "$sid" -p State --value 2>/dev/null || true)"
        suid="$(loginctl show-session "$sid" -p User --value 2>/dev/null || true)"
        suser="$(loginctl show-session "$sid" -p Name --value 2>/dev/null || true)"

        case "$stype" in
          wayland|x11) ;;
          *) continue ;;
        esac
        [ "$sstate" = "active" ] || continue
        [ -n "$suid" ] || continue
        [ -n "$suser" ] || continue
        [ -S "/run/user/$suid/bus" ] || continue

        runuser -u "$suser" -- \
          env "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$suid/bus" \
          notify-send --app-name="Switch RCM" --urgency="$urgency" "$summary" "$body" \
          || true
      done
    '';
  };
in {
```

Notes for the implementer:
- `loginctl show-session -p User --value` returns the **numeric UID**; `-p Name --value` returns the **username**. We need the UID for the bus path (`/run/user/<uid>/bus`) and the username for `runuser`.
- Every external call is guarded with `|| true` / `continue` so one bad session never fails the whole broadcast.
- `runuser` comes from `util-linux`, present in the default system path; it is invoked here from within a root service, which is allowed.

- [ ] **Step 2: Add the injection + notification services to `config`**

In the `config = mkIf cfg.enable { ... }` block, after the `services.udev.extraRules` attribute, add the systemd services:

```nix
    systemd.services.switch-rcm-inject = {
      description = "Inject hekate RCM payload into Nintendo Switch";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.fusee-nano} ${cfg.payload}";
      };

      onFailure = mkIf cfg.notify ["switch-rcm-notify-fail.service"];

      # On success, notify (best-effort) when enabled.
      postStart = mkIf cfg.notify ''
        ${lib.getExe notifyBroadcast} normal "Nintendo Switch" "hekate payload sent successfully."
      '';
    };

    systemd.services.switch-rcm-notify-fail = mkIf cfg.notify {
      description = "Notify that Nintendo Switch RCM injection failed";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${lib.getExe notifyBroadcast} critical "Nintendo Switch" "hekate payload injection FAILED. Check: journalctl -u switch-rcm-inject"'';
      };
    };
```

Notes:
- `lib.getExe pkgs.fusee-nano` resolves to the `fusee-nano` binary (the package sets `meta.mainProgram = "fusee-nano"`).
- `postStart` (a NixOS convenience that maps to `ExecStartPost`) only runs on successful `ExecStart`, so it is the success path. `onFailure` triggers the dedicated failure unit. This split is how we pass outcome through a oneshot.
- `mkIf cfg.notify` on `onFailure` / `postStart` cleanly drops them when notifications are disabled.

- [ ] **Step 3: Format**

Run: `nix fmt modules/nixos/hardware/nintendo-switch.nix`
Expected: reformatted/clean, exit 0.

- [ ] **Step 4: Verify it still evaluates standalone**

Run the same eval as Task 2 Step 3:
```bash
nix eval --impure --expr '
  let
    pkgs = import <nixpkgs> {};
    m = import ./modules/nixos/hardware/nintendo-switch.nix {
      config = { rat.hardware.nintendoSwitch.rcm.enable = false; };
      inherit (pkgs) lib;
      inherit pkgs;
    };
  in builtins.attrNames m.options.rat.hardware.nintendoSwitch.rcm
'
```
Expected: `[ "enable" "notify" "payload" ]`. Confirms the larger `let` block and `config` body still parse. (With `enable = false`, the `config` body is under `mkIf` and not forced, so `writeShellApplication`/`fusee-nano` are not built by this check.)

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/hardware/nintendo-switch.nix
git commit -m "feat(hardware): add Switch RCM injection service + notification broadcast"
```

---

## Task 4: Wire the module into the hardware import set

**Files:**
- Modify: `modules/nixos/hardware/default.nix:4-14` (the `imports` list)

- [ ] **Step 1: Add the import**

In `modules/nixos/hardware/default.nix`, add `./nintendo-switch.nix` to the `imports` list (keep it alphabetically reasonable — between `./nvidia.nix` and `./openrgb.nix`, or grouped sensibly). The list becomes:

```nix
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./nintendo-switch.nix
    ./nvidia.nix
    ./openrgb.nix
    ./printing.nix
    ./security-key.nix
    ./topping-e2x2.nix
    ./udisks2.nix
    ./usbmuxd.nix
  ];
```

- [ ] **Step 2: Format**

Run: `nix fmt modules/nixos/hardware/default.nix`
Expected: clean, exit 0.

- [ ] **Step 3: Verify the option now exists in a host eval (disabled everywhere)**

The module is now imported but not enabled on any host. Confirm it evaluates within the real module system by reading the option's default on ulysses:

Run:
```bash
nix eval .#nixosConfigurations.ulysses.config.rat.hardware.nintendoSwitch.rcm.enable
```
Expected: `false` (module present, default off, full module system evaluates cleanly).

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/hardware/default.nix
git commit -m "feat(hardware): import nintendo-switch module"
```

---

## Task 5: Enable on ulysses

**Files:**
- Modify: `systems/ulysses/default.nix` (the `rat = { ... };` block, around line 86+)

- [ ] **Step 1: Enable the module**

In `systems/ulysses/default.nix`, inside the existing `rat = { ... };` attrset, add the hardware enablement. If there is an existing `rat.hardware = { ... };` grouping, nest it there; otherwise add a top-level line within `rat`:

```nix
    hardware.nintendoSwitch.rcm.enable = true;
```

(If the file groups hardware options elsewhere, place it consistently with `rat.hardware.usbmuxd.enable` / similar if present. Leave `payload` and `notify` at defaults.)

- [ ] **Step 2: Format**

Run: `nix fmt systems/ulysses/default.nix`
Expected: clean, exit 0.

- [ ] **Step 3: Verify enabled in eval**

Run:
```bash
nix eval .#nixosConfigurations.ulysses.config.rat.hardware.nintendoSwitch.rcm.enable
```
Expected: `true`.

- [ ] **Step 4: Verify the udev rule and service are present in the built config**

Run:
```bash
nix eval --raw .#nixosConfigurations.ulysses.config.services.udev.extraRules | grep 7321
```
Expected: prints the line containing `ATTR{idProduct}=="7321"` and `switch-rcm-inject.service`.

Run:
```bash
nix eval .#nixosConfigurations.ulysses.config.systemd.services.switch-rcm-inject.description
```
Expected: `"Inject hekate RCM payload into Nintendo Switch"`.

- [ ] **Step 5: Build the full ulysses toplevel**

Run (offload to server if local is slow):
```bash
nix build .#nixosConfigurations.ulysses.config.system.build.toplevel
```
Expected: builds successfully. This forces evaluation of `pkgs.hekate-payload`, `pkgs.fusee-nano`, and the `notifyBroadcast` wrapper, catching any real build errors.

- [ ] **Step 6: Commit**

```bash
git add systems/ulysses/default.nix
git commit -m "feat(ulysses): enable Nintendo Switch RCM auto-payload"
```

---

## Task 6: Final verification & manual test notes

**Files:** none (verification only).

- [ ] **Step 1: Full format check**

Run: `nix fmt`
Expected: no files changed (everything already formatted).

- [ ] **Step 2: Flake check**

Run: `nix flake check --no-build`
Expected: passes (in particular, the package updateScript check is happy with `hekate-payload`).

- [ ] **Step 3: Deploy to ulysses**

Run: `nix run .#switch -- --build-host iserlohn`
(or `nix run .#boot` first for a safer boot-time test). Expected: rebuild succeeds.

- [ ] **Step 4: Manual hardware test (documented, performed by the user)**

Record these steps in the PR description; the user runs them with the actual console:
1. Put the Switch (vulnerable Erista) into RCM mode and plug it into ulysses via USB.
2. Watch the journal: `journalctl -fu switch-rcm-inject` — expect `fusee-nano` output ending in `[+] Sent 0x... bytes`.
3. A mako notification "Nintendo Switch — hekate payload sent successfully." appears.
4. The Switch boots into the hekate menu.
5. Failure path (optional): unplug mid-inject or use a non-vulnerable unit and confirm the `switch-rcm-notify-fail.service` notification fires only when injection actually starts and fails. (A non-vulnerable Switch never presents `0955:7321`, so nothing runs — that is expected, not a failure notification.)

---

## Self-Review Notes (already applied)

- **Spec coverage:** package (Task 1), module options/udev (Task 2), inject service + dual-path notifications (Task 3), import (Task 4), ulysses enable (Task 5), verification (Task 6) — every spec section maps to a task.
- **Type/name consistency:** service names `switch-rcm-inject` / `switch-rcm-notify-fail`, wrapper `switch-rcm-notify`, option path `rat.hardware.nintendoSwitch.rcm.{enable,payload,notify}`, package attr `hekate-payload`, payload path `share/hekate/hekate_ctcaer.bin` — used identically everywhere.
- **Open implementation detail to confirm during Task 3:** `loginctl show-session -p User` returns UID and `-p Name` returns username (verified against systemd's documented session properties). If a future systemd renames these, Step 4 evals still pass but the runtime broadcast would no-op safely (guarded by `|| true`); the manual test (Task 6 Step 4) is the real confirmation.

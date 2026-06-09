# Sunshine Game Streaming on Ulysses — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add LAN game streaming on Ulysses via Sunshine, streaming an on-demand Hyprland virtual display (Steam Big Picture by default) to Moonlight clients (iPad, Switch), with NVENC encoding and SOPS-seeded web-UI credentials.

**Architecture:** A new NixOS module `modules/nixos/games/sunshine.nix` (following the existing `steam.nix`/`aagl.nix` patterns) wraps the upstream `services.sunshine` module. It adds a `sunshine` group for credential access, `uinput` group membership for input injection, a SOPS secret for the hashed web-UI credentials, and two declarative Moonlight apps whose `prep-cmd` hooks drive a committed `writeShellApplication` that creates/destroys a Hyprland headless output sized to the client. A nixpkgs patch (PR #521906) bumps Sunshine to a current, security-fixed version.

**Tech Stack:** Nix / NixOS modules, flake-parts, sops-nix, Hyprland (`hyprctl`), Sunshine/Moonlight, NVENC (RTX 5090).

---

## Verification environment note

This is a NixOS config repo. There is no unit-test framework — verification is done with `nix` evaluation/build commands and (for runtime steps) on the live Ulysses host after a rebuild. Each task's "test" is the appropriate `nix` command and/or a runtime check. Builds can be offloaded with `--build-host iserlohn` per repo conventions, but evaluation checks run locally.

Throughout, the working directory is the repo root: `/home/awilliams/Development/nix-config`.

---

## File Structure

- **Create** `modules/nixos/games/sunshine.nix` — the entire Sunshine module: options (`rat.gaming.sunshine.{enable,users,openFirewall}`), the `sunshine` group, group membership, SOPS secret wiring, `services.sunshine` config (settings + applications), the `sunshine-virtual-display` script, and the empty-users warning.
- **Modify** `modules/nixos/games/default.nix` — add `./sunshine.nix` to `imports`.
- **Modify** `flake.nix` — add the `nixpkgs-patch-521906` input under `#region nixpkgs patches`.
- **Create** `secrets/sunshine.yaml` — SOPS-encrypted hashed credential JSON (manual bootstrap step).
- **Modify** `systems/ulysses/default.nix` — enable `rat.gaming.sunshine` in the existing `gaming` block.

Single subsystem, single plan.

---

## Task 1: Add the nixpkgs patch for current Sunshine

**Files:**
- Modify: `flake.nix` (under `#region nixpkgs patches`, around line 28-32)

- [ ] **Step 1: Add the patch input**

In `flake.nix`, inside the `#region nixpkgs patches` block, after the existing `nixpkgs-patch-528519` entry (before `#endregion` at line ~34), add:

```nix
    # sunshine: 2025.924.154138 -> 2026.516.143833. The version in nixpkgs is
    # ~1yr stale with unfixed security vulnerabilities (upstream label
    # "1.severity: security"). Upstream refactored their build (prebuilt ffmpeg
    # fetch, boost 1.89 pin, renamed systemd unit, new build deps), so this is a
    # package rework rather than a simple version bump. (NixOS/nixpkgs#521906)
    nixpkgs-patch-521906 = {
      url = "https://github.com/NixOS/nixpkgs/pull/521906.diff";
      flake = false;
    };
```

- [ ] **Step 2: Update the flake lock for the new input**

Run: `nix flake lock`
Expected: Adds a lock entry for `nixpkgs-patch-521906`; no errors.

- [ ] **Step 3: Verify the patch applies and the patched package builds**

The `patcher.nix` module auto-discovers `nixpkgs-patch-*` inputs and applies them to nixpkgs. Build the patched Sunshine package through a host's pkgs set to confirm the diff applies cleanly:

Run: `nix build .#nixosConfigurations.ulysses.pkgs.sunshine --no-link 2>&1 | tail -20`
Expected: Builds successfully (the patch applies; Sunshine `2026.516.143833` builds on `x86_64-linux`). If the patch fails to apply, the `patcher.nix` `failureHook` prints the failed hunks — read them before proceeding.

(Tip: add `--builders '' --build-host iserlohn` style offload per repo convention if the local build is slow. Evaluation alone can be checked with `nix eval .#nixosConfigurations.ulysses.pkgs.sunshine.version --raw`.)

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "flake: patch in sunshine 2026.516.143833 (NixOS/nixpkgs#521906)"
```

---

## Task 2: Create the Sunshine module skeleton (options + gating + import)

This task creates the module with options and an empty-but-valid config block, and wires it into the games import list. No `services.sunshine` yet — that comes in later tasks so each step stays small and independently evaluable.

**Files:**
- Create: `modules/nixos/games/sunshine.nix`
- Modify: `modules/nixos/games/default.nix` (imports list, lines 9-12)

- [ ] **Step 1: Create the module with options only**

Create `modules/nixos/games/sunshine.nix`:

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.modules) mkIf;
  inherit (lib) types genAttrs optional;
  cfg = config.rat.gaming.sunshine;
in {
  options.rat.gaming.sunshine = {
    enable = mkEnableOption "Sunshine game streaming host";

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["awilliams"];
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
    # Non-fatal guard: Sunshine still streams video without input injection,
    # but Moonlight gamepad/keyboard/mouse will silently fail.
    warnings = optional (cfg.users == []) ''
      rat.gaming.sunshine is enabled but `users` is empty. No user has been
      added to the `uinput`/`sunshine` groups, so Moonlight input injection
      and credential-file access will not work. Set
      `rat.gaming.sunshine.users = [ "<username>" ];`.
    '';
  };
}
```

- [ ] **Step 2: Add the module to the games imports**

In `modules/nixos/games/default.nix`, change the `imports` list (lines 9-12) from:

```nix
  imports = [
    ./aagl.nix
    ./steam.nix
  ];
```

to:

```nix
  imports = [
    ./aagl.nix
    ./steam.nix
    ./sunshine.nix
  ];
```

- [ ] **Step 3: Verify the configuration still evaluates**

The module is gated and Ulysses hasn't enabled it yet, so this only checks the option definitions and import are valid.

Run: `nix eval .#nixosConfigurations.ulysses.config.rat.gaming.sunshine.enable`
Expected: `false`

Run: `nix eval .#nixosConfigurations.ulysses.config.rat.gaming.sunshine.openFirewall`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/games/sunshine.nix modules/nixos/games/default.nix
git commit -m "feat(sunshine): add module skeleton with options and gating"
```

---

## Task 3: Add the sunshine group and user/group membership

**Files:**
- Modify: `modules/nixos/games/sunshine.nix` (the `config` block)

- [ ] **Step 1: Add group creation and membership to the config block**

In `modules/nixos/games/sunshine.nix`, inside the `config = mkIf (...) { ... }` block, add the following **above** the `warnings` attribute:

```nix
    # Dedicated group for credential-file access (distinct from uinput, even
    # though the user set overlaps today — credential access != input access).
    users.groups.sunshine = {};

    # Grant each permitted user uinput access (input injection) and sunshine
    # group membership (credentials_file read).
    users.users = genAttrs cfg.users (_: {
      extraGroups = ["uinput" "sunshine"];
    });
```

- [ ] **Step 2: Temporarily enable on Ulysses to verify membership evaluates**

To verify group membership wiring without committing the Ulysses change yet, evaluate with an override. Run:

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.users.users.awilliams.extraGroups
' --json
```

Expected: a JSON array that **includes** `"uinput"` and `"sunshine"` (alongside the user's other groups).

- [ ] **Step 3: Verify the group exists when enabled**

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.users.groups ? sunshine
'
```

Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "feat(sunshine): add sunshine group and uinput/sunshine membership"
```

---

## Task 4: Create the secrets file (manual SOPS bootstrap)

This task produces the hashed credential JSON and encrypts it. It requires the `sunshine` binary (now built via Task 1) and an interactive choice of password, so it is a documented manual step. The `.sops.yaml` creation rule already covers `secrets/*.yaml` for all hosts including `host_ulysses` — no `.sops.yaml` edit needed.

**Files:**
- Create: `secrets/sunshine.yaml`

- [ ] **Step 1: Generate the hashed credential JSON**

`sunshine --creds <user> <pass>` writes the credential state (username + salted hash) into Sunshine's state file. Run it against a temporary state dir so it doesn't touch any real config:

```bash
TMPSTATE="$(mktemp -d)"
nix shell .#nixosConfigurations.ulysses.pkgs.sunshine -c \
  env XDG_CONFIG_HOME="$TMPSTATE" sunshine --creds admin 'CHOOSE_A_STRONG_PASSWORD'
cat "$TMPSTATE/sunshine/sunshine_state.json"
```

Expected: prints a JSON object containing `username`, `salt`, and `hash` fields (the exact schema is Sunshine's; it contains **no plaintext password**). Copy this JSON.

> Replace `admin` and `CHOOSE_A_STRONG_PASSWORD` with your desired web-UI username and password. The password is only used to compute the hash here; it is not stored.

- [ ] **Step 2: Create and encrypt the secrets file**

Create the SOPS file with a single key `sunshine/credentials` whose value is the **JSON string** from Step 1. Easiest path:

```bash
# Create the plaintext structure first, then encrypt in place.
cat > secrets/sunshine.yaml <<'EOF'
sunshine/credentials: |
  PASTE_THE_JSON_FROM_STEP_1_HERE
EOF

sops --encrypt --in-place secrets/sunshine.yaml
```

> The value must be the full JSON content of `sunshine_state.json` as a multi-line string. After `sops --encrypt --in-place`, the file is encrypted and safe to commit.

- [ ] **Step 3: Verify it decrypts to valid JSON**

```bash
sops --decrypt secrets/sunshine.yaml
```

Expected: shows `sunshine/credentials: |` followed by the JSON you pasted (with `username`/`salt`/`hash`). Confirm it is valid JSON.

- [ ] **Step 4: Clean up the temp state dir**

```bash
rm -rf "$TMPSTATE"
```

- [ ] **Step 5: Commit**

```bash
git add secrets/sunshine.yaml
git commit -m "secrets(sunshine): add SOPS-encrypted web-UI credentials"
```

---

## Task 5: Wire the SOPS secret into the module

**Files:**
- Modify: `modules/nixos/games/sunshine.nix` (the `config` block)

- [ ] **Step 1: Add the sops.secrets entry**

In `modules/nixos/games/sunshine.nix`, inside the `config` block, add the following **above** the `warnings` attribute (after the `users.users` block from Task 3):

```nix
    # SOPS-decrypted hashed credential JSON, group-readable, in /run (tmpfs).
    # Path defaults to /run/secrets/sunshine/credentials.
    sops.secrets."sunshine/credentials" = {
      sopsFile = ../../../secrets/sunshine.yaml;
      mode = "0440";
      group = "sunshine";
    };
```

> The relative path `../../../secrets/sunshine.yaml` is correct from `modules/nixos/games/`. The default `sops.defaultSopsFile` is `secrets/default.yaml`, so an explicit `sopsFile` is required for this per-service secret (matching the pattern used by every other service module, e.g. `arrs.yaml`).

- [ ] **Step 2: Verify the secret path resolves under enable**

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.sops.secrets."sunshine/credentials".path
' --raw
```

Expected: `/run/secrets/sunshine/credentials`

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "feat(sunshine): wire SOPS credentials secret into module"
```

---

## Task 6: Add the virtual-display script

This task adds the `sunshine-virtual-display` `writeShellApplication` to the module's `let` block. It is not referenced by `services.sunshine` yet (that is Task 8), so this task only needs to evaluate/build the script derivation.

**Files:**
- Modify: `modules/nixos/games/sunshine.nix` (the `let` block; add `pkgs` to the module args)

- [ ] **Step 1: Add `pkgs` to module arguments**

Change the module header of `modules/nixos/games/sunshine.nix` from:

```nix
{
  config,
  lib,
  ...
}: let
```

to:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
```

- [ ] **Step 2: Add the script derivation to the `let` block**

In the `let` block (after `cfg = config.rat.gaming.sunshine;`), add:

```nix
  # On-demand Hyprland headless output management. The headless output name
  # (HEADLESS-N) is not known until after creation, so this logic lives in a
  # script rather than inline hyprctl one-liners. Drives the prep-cmd hooks.
  #
  # Subcommands:
  #   create        - create+size headless output, move stream workspace to it
  #   destroy       - move stream workspace back, remove headless output
  #   create-steam  - create, then switch the existing Steam into Big Picture
  #   destroy-steam - exit Big Picture, then destroy
  #
  # Sunshine sets SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS in the prep-cmd environment.
  virtualDisplay = pkgs.writeShellApplication {
    name = "sunshine-virtual-display";
    runtimeInputs = with pkgs; [hyprland jq steam];
    text = ''
      set -euo pipefail

      STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/sunshine-virtual-display"
      mkdir -p "$STATE_DIR"
      NAME_FILE="$STATE_DIR/headless-name"

      WIDTH="''${SUNSHINE_CLIENT_WIDTH:-1920}"
      HEIGHT="''${SUNSHINE_CLIENT_HEIGHT:-1080}"
      FPS="''${SUNSHINE_CLIENT_FPS:-60}"

      STREAM_WS="stream"

      create_output() {
        # Snapshot existing headless outputs, create one, diff to find its name.
        before="$(hyprctl monitors -j | jq -r '.[].name' | grep '^HEADLESS-' || true)"
        hyprctl output create headless
        sleep 0.5
        after="$(hyprctl monitors -j | jq -r '.[].name' | grep '^HEADLESS-' || true)"
        name="$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -n1)"
        if [ -z "$name" ]; then
          echo "sunshine-virtual-display: failed to determine new headless output name" >&2
          exit 1
        fi
        echo "$name" > "$NAME_FILE"

        # Size the headless output to the client's requested geometry.
        hyprctl keyword monitor "$name,''${WIDTH}x''${HEIGHT}@''${FPS},auto,1.0"

        # Move the dedicated streaming workspace onto the headless output and focus it.
        hyprctl dispatch moveworkspacetomonitor "$STREAM_WS" "$name"
        hyprctl dispatch workspace "$STREAM_WS"
      }

      destroy_output() {
        # Move the streaming workspace back to the primary monitor, then remove.
        primary="$(hyprctl monitors -j | jq -r '.[] | select(.name | startswith("HEADLESS-") | not) | .name' | head -n1)"
        if [ -n "$primary" ]; then
          hyprctl dispatch moveworkspacetomonitor "$STREAM_WS" "$primary" || true
        fi
        if [ -f "$NAME_FILE" ]; then
          name="$(cat "$NAME_FILE")"
          hyprctl output remove "$name" || true
          rm -f "$NAME_FILE"
        fi
      }

      case "''${1:-}" in
        create)
          create_output
          ;;
        destroy)
          destroy_output
          ;;
        create-steam)
          create_output
          steam steam://open/bigpicture >/dev/null 2>&1 || true
          ;;
        destroy-steam)
          steam steam://close/bigpicture >/dev/null 2>&1 || true
          sleep 0.5
          destroy_output
          ;;
        *)
          echo "usage: sunshine-virtual-display {create|destroy|create-steam|destroy-steam}" >&2
          exit 1
          ;;
      esac
    '';
  };
```

- [ ] **Step 3: Verify the script derivation builds**

`writeShellApplication` runs `shellcheck` at build time, so this also lint-checks the script.

```bash
nix build --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      pkgs = flake.nixosConfigurations.ulysses.pkgs;
  in pkgs.writeShellApplication {
    name = "sunshine-virtual-display-probe";
    runtimeInputs = with pkgs; [ hyprland jq steam ];
    text = builtins.readFile ./modules/nixos/games/sunshine.nix;
  }
' --no-link 2>&1 | tail -5 || true
```

> Note: the probe above is only a rough shellcheck smoke test of the file; the authoritative check is Task 8's full system build, which instantiates the real `virtualDisplay` derivation. If you prefer, skip directly to verifying via `nix eval` that the module still evaluates:

```bash
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

Expected: prints a `.drv` path with no evaluation error (the module with the new `let` binding evaluates; the binding is unused so far but must not error).

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "feat(sunshine): add on-demand Hyprland virtual-display script"
```

---

## Task 7: Add Sunshine settings (declarative, NVENC + credentials)

**Files:**
- Modify: `modules/nixos/games/sunshine.nix` (the `config` block)

- [ ] **Step 1: Add the `services.sunshine` base config with settings**

In `modules/nixos/games/sunshine.nix`, inside the `config` block (after the `sops.secrets` block, before `warnings`), add:

```nix
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true; # required for KMS/DRM screen capture on Wayland
      openFirewall = cfg.openFirewall;

      settings = {
        sunshine_name = "ulysses";
        encoder = "nvenc"; # pin NVENC for reproducibility (RTX 5090)
        credentials_file = config.sops.secrets."sunshine/credentials".path;
      };
    };
```

- [ ] **Step 2: Verify settings render**

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.services.sunshine.settings.encoder
' --raw
```

Expected: `nvenc`

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.services.sunshine.settings.credentials_file
' --raw
```

Expected: `/run/secrets/sunshine/credentials`

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "feat(sunshine): declarative settings (nvenc, name, credentials_file)"
```

---

## Task 8: Add the Moonlight applications (Steam Big Picture + Desktop)

**Files:**
- Modify: `modules/nixos/games/sunshine.nix` (the `services.sunshine` block)

- [ ] **Step 1: Add the `applications` attribute**

In `modules/nixos/games/sunshine.nix`, extend the `services.sunshine` block by adding an `applications` attribute (after `settings`):

```nix
      applications = {
        env.PATH = "$(PATH):${pkgs.hyprland}/bin";
        apps = [
          {
            name = "Steam Big Picture";
            prep-cmd = [
              {
                do = "${virtualDisplay}/bin/sunshine-virtual-display create-steam";
                undo = "${virtualDisplay}/bin/sunshine-virtual-display destroy-steam";
              }
            ];
            auto-detach = "true";
            exclude-global-prep-cmd = "false";
          }
          {
            name = "Desktop (Virtual Display)";
            prep-cmd = [
              {
                do = "${virtualDisplay}/bin/sunshine-virtual-display create";
                undo = "${virtualDisplay}/bin/sunshine-virtual-display destroy";
              }
            ];
            auto-detach = "true";
            exclude-global-prep-cmd = "false";
          }
        ];
      };
```

> The `image-path = "steam.png"` from the design is omitted because it requires an asset path that does not exist in this repo; Moonlight falls back to a default tile. Add a real image path later if desired.

- [ ] **Step 2: Verify the applications render and reference the script**

```bash
nix eval --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in map (a: a.name) sys.config.services.sunshine.applications.apps
' --json
```

Expected: `["Steam Big Picture","Desktop (Virtual Display)"]`

- [ ] **Step 3: Build the full system to confirm everything (incl. the script + patched package) resolves**

This is the authoritative build check: it instantiates the `virtualDisplay` derivation (shellcheck runs), the patched Sunshine package, the systemd user unit, and the SOPS secret wiring together.

```bash
nix build --impure --expr '
  let flake = builtins.getFlake (toString ./.);
      sys = flake.nixosConfigurations.ulysses.extendModules {
        modules = [{ rat.gaming.sunshine = { enable = true; users = [ "awilliams" ]; }; }];
      };
  in sys.config.system.build.toplevel
' --no-link 2>&1 | tail -20
```

Expected: builds successfully. (Offload with repo conventions if slow.) If the `services.sunshine` systemd user unit fails to resolve against the patched package (the renamed-unit risk from the design), investigate here before proceeding — but per the upstream module reading, it builds its own unit and calls `getExe cfg.package`, so it should resolve.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "feat(sunshine): add Steam Big Picture and Desktop Moonlight apps"
```

---

## Task 9: Enable Sunshine on Ulysses

**Files:**
- Modify: `systems/ulysses/default.nix` (the existing `gaming` block, around lines 185-190)

- [ ] **Step 1: Enable in the Ulysses gaming block**

In `systems/ulysses/default.nix`, find the existing `gaming` block:

```nix
    gaming = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
    };
```

and change it to:

```nix
    gaming = {
      enable = true;
      animeGameLaunchers.enable = true;
      steam.enable = true;
      sunshine = {
        enable = true;
        users = ["awilliams"];
        # openFirewall defaults to true
      };
    };
```

> Match the exact indentation and attribute-path style already used in that block (it is nested under the host's `rat` config — verify the surrounding context and keep it consistent).

- [ ] **Step 2: Verify the real (non-override) config now has Sunshine enabled**

```bash
nix eval .#nixosConfigurations.ulysses.config.rat.gaming.sunshine.users --json
```

Expected: `["awilliams"]`

```bash
nix eval .#nixosConfigurations.ulysses.config.services.sunshine.enable
```

Expected: `true`

- [ ] **Step 3: Build the real toplevel (no override)**

```bash
nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link 2>&1 | tail -20
```

Expected: builds successfully.

- [ ] **Step 4: Run flake checks**

Run: `nix flake check 2>&1 | tail -30`
Expected: no new failures introduced by these changes. (This may take a while; the repo notes it can be slow.)

- [ ] **Step 5: Commit**

```bash
git add systems/ulysses/default.nix
git commit -m "feat(ulysses): enable Sunshine game streaming"
```

---

## Task 10: Deploy and runtime-verify on Ulysses

This task runs on the live Ulysses host and is interactive (requires the Moonlight clients). It is the acceptance test for the whole feature.

**Files:** none (deployment + manual verification)

- [ ] **Step 1: Boot-test the configuration (safer than immediate switch)**

Run: `nix run .#boot`
Expected: builds and sets the new generation for next boot without disrupting the running session. (Optionally use `--build-host iserlohn` to offload the build.)

- [ ] **Step 2: Activate**

Run: `nix run .#switch`
Expected: activation succeeds. If anything is wrong with the user service, the desktop session remains usable (Sunshine is a user service).

- [ ] **Step 3: Verify group membership**

Run: `id awilliams`
Expected: output includes both `uinput` and `sunshine` groups. (If the session predates the group add, log out/in or reboot so the new groups apply.)

- [ ] **Step 4: Verify the SOPS secret decrypted with correct ownership**

Run: `ls -l /run/secrets/sunshine/credentials`
Expected: exists, mode `-r--r-----` (0440), group `sunshine`.

Run: `sudo cat /run/secrets/sunshine/credentials`
Expected: the hashed credential JSON (username/salt/hash).

- [ ] **Step 5: Verify the Sunshine user service is running**

Run: `systemctl --user status sunshine`
Expected: `active (running)`, started within the `graphical-session.target`. If failed, check `journalctl --user -u sunshine -e`.

- [ ] **Step 6: Verify web UI accepts the pre-seeded credentials**

Open `https://localhost:47990` in a browser on Ulysses. Log in with the username/password chosen in Task 4.
Expected: login succeeds with **no first-run "create credentials" prompt** — confirming the SOPS-seeded `credentials_file` was loaded.

- [ ] **Step 7: Pair and stream to the iPad**

On the iPad Moonlight app, confirm Ulysses is discovered (avahi/mDNS). Pair using the PIN shown in the Sunshine web UI. Launch "Steam Big Picture".
Expected:
- A `HEADLESS-N` output is created (verify on Ulysses: `hyprctl monitors -j | jq -r '.[].name'` shows it during the session).
- Steam Big Picture appears on the stream, **not** on the physical DP-1 monitor.
- Gamepad/keyboard/mouse input works (input injection via uinput).
- On disconnect: Big Picture exits, the streaming workspace returns to the primary monitor, and the `HEADLESS-N` output is removed.

- [ ] **Step 8: Stream to the Switch**

Repeat Step 7 with the Switch Moonlight homebrew client (expect 1080p/60). Confirm the headless output is sized to the client request and the session is playable.

- [ ] **Step 9: Verify the "Desktop (Virtual Display)" fallback app**

From either client, launch "Desktop (Virtual Display)".
Expected: a headless output is created and the desktop streams to it without launching Steam; teardown removes the output on disconnect.

- [ ] **Step 10: Final commit (if any runtime fixups were needed)**

If Steps 7-9 revealed a needed adjustment (e.g., workspace name, monitor scaling, `sleep` timing in the script), make the minimal fix in `modules/nixos/games/sunshine.nix`, re-run `nix run .#switch`, re-verify, and commit:

```bash
git add modules/nixos/games/sunshine.nix
git commit -m "fix(sunshine): <describe runtime fixup>"
```

> If the Hyprland headless output misbehaves on NVIDIA + wlroots (the design's noted risk), the documented Plan B is evdi via `virtual-display-linux`. That is a separate follow-up, not part of this plan.

---

## Self-Review

**Spec coverage:**
- LAN streaming to iPad/Switch, NVENC → Tasks 7, 8, 10 ✓
- On-demand Hyprland headless virtual display (not evdi) → Task 6 (script), Task 8 (prep-cmd wiring), Task 10 (runtime verify); evdi Plan B noted in Task 10 ✓
- New `modules/nixos/games/sunshine.nix` following `steam.nix` pattern; `rat.gaming.sunshine.{enable,users,openFirewall}` → Task 2 ✓
- `users` list → `uinput` + `sunshine` group membership → Task 3 ✓
- Warning (not assertion) when enable && users empty → Task 2 ✓
- `capSysAdmin`, `autoStart`, `openFirewall` default true → Tasks 2, 7 ✓
- nixpkgs patch PR #521906 → Task 1 ✓
- Fully declarative settings (nvenc, sunshine_name) + applications → Tasks 7, 8 ✓
- Two apps: Steam Big Picture (Option B, single shared Steam) + Desktop fallback → Task 8, Task 6 (script subcommands) ✓
- Virtual-display logic in committed `writeShellApplication` → Task 6 ✓
- SOPS hashed-credential JSON, group-readable in /run, bootstrap step → Tasks 4, 5 ✓
- Ulysses wiring → Task 9 ✓
- Systemd-unit-rename verification → Task 8 Step 3, Task 10 Step 5 ✓

No spec requirement is left without a task.

**Placeholder scan:** The only intentional user-supplied values are the web-UI username/password in Task 4 (inherent to credential bootstrap) and a possible image asset (explicitly deferred in Task 8). No "TBD"/"implement later"/vague-error-handling placeholders. All code steps show complete code.

**Type/name consistency:** Script subcommands (`create`, `destroy`, `create-steam`, `destroy-steam`) defined in Task 6 match exactly the `prep-cmd` references in Task 8. The secret key `"sunshine/credentials"` is identical across Tasks 4, 5, 7, 10. The `virtualDisplay` `let` binding (Task 6) matches its `${virtualDisplay}/bin/sunshine-virtual-display` references (Task 8), and the script `name` (`sunshine-virtual-display`) matches the binary path. Option paths `rat.gaming.sunshine.{enable,users,openFirewall}` are consistent across Tasks 2, 9.

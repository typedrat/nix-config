# In-Repo nixpkgs + home-manager Patcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the `nixpkgs-patcher` flake input with an in-repo helper that patches both nixpkgs (`nixpkgs-patch-*` inputs) and home-manager (`home-manager-patch-*` inputs).

**Architecture:** A plain Nix file `modules/extra/flake-parts/patcher.nix` exposes `patchesFromInputs` and `patchSource` helpers. `nixos-hosts.nix` imports it and uses it inside `mkNixosSystem`, replacing the call to `nixpkgs-patcher.lib.nixosSystem` with a direct `import "${patchedNixpkgs}/nixos/lib/eval-config.nix"`. The home-manager NixOS module is moved from `systems/default.nix` into `nixos-hosts.nix` so the patcher can substitute the patched source path.

**Tech Stack:** Nix flake-parts, nixpkgs `pkgs.applyPatches`, `stdenvNoCC.mkDerivation`

---

### Task 1: Create `modules/extra/flake-parts/patcher.nix`

**Files:**
- Create: `modules/extra/flake-parts/patcher.nix`

**Step 1: Write the file**

```nix
# modules/extra/flake-parts/patcher.nix
#
# Drop-in replacement for the nixpkgs-patcher flake input.
# Exposes helpers to patch nixpkgs and home-manager from flake inputs
# named with a given prefix (e.g. "nixpkgs-patch-*", "home-manager-patch-*").
let
  # Wrap a raw flake input path in a derivation so it has a usable .name.
  wrapPatch = pkgs: patch:
    pkgs.stdenvNoCC.mkDerivation {
      inherit (patch) name;
      phases = [ "installPhase" ];
      installPhase = ''
        cp -r ${patch.value.outPath} $out
      '';
    };

  # Collect all inputs whose names start with `prefix`, wrap each one.
  patchesFromInputs = { inputs, pkgs, prefix }:
    let
      matching = pkgs.lib.filterAttrs (n: _: pkgs.lib.hasPrefix prefix n) inputs;
      pairs    = pkgs.lib.attrsToList matching;
    in
    map (wrapPatch pkgs) pairs;

  # Apply a list of patches to a source tree using pkgs.applyPatches.
  # Provides a bat-based failure hook (same UX as nixpkgs-patcher).
  # Only call this when patches != [].
  patchSource = { src, name, patches, pkgs }:
    pkgs.applyPatches {
      inherit name src patches;
      nativeBuildInputs =
        [ pkgs.bat ]
        ++ pkgs.lib.optionals pkgs.stdenv.buildPlatform.isLinux [ pkgs.breakpointHook ];
      failureHook = ''
        failedPatches=$(find . -name "*.rej")
        for failedPatch in $failedPatches; do
          echo "────────────────────────────────────────────────────────────────────────────────"
          originalFile="${src}/''${failedPatch%.rej}"
          echo "Original file without any patches: $originalFile"
          echo "Failed hunks of this file:"
          bat --pager never --style plain $failedPatch
        done
        echo "────────────────────────────────────────────────────────────────────────────────"
        echo "Applying some patches failed. Check the build log above this message."
      '';
    };

  # Produce a version string for a patched nixpkgs, used in versionSuffix.
  nixpkgsVersion = { nixpkgs, patches }:
    "${builtins.substring 0 8 (nixpkgs.lastModifiedDate or "19700101")}"
    + ".${nixpkgs.shortRev or "dirty"}"
    + (if patches != [] then "-patched" else "");
in
{
  inherit patchesFromInputs patchSource nixpkgsVersion;
}
```

**Step 2: Verify the file parses**

Run: `nix eval --expr 'builtins.attrNames (import ./modules/extra/flake-parts/patcher.nix)'`
from `/home/awilliams/Development/nix-config`.

Expected output: `[ "nixpkgsVersion" "patchesFromInputs" "patchSource" ]`

**Step 3: Commit**

```bash
git add modules/extra/flake-parts/patcher.nix
git commit -m "Add in-repo patcher helpers for nixpkgs and home-manager"
```

---

### Task 2: Rewrite `modules/extra/flake-parts/nixos-hosts.nix`

**Files:**
- Modify: `modules/extra/flake-parts/nixos-hosts.nix`

**Context:** The file currently starts with `{nixpkgs-patcher}: { self, inputs, ... }` — a curried function. After this task it becomes a plain flake-parts module `{ self, inputs, ... }` (no outer wrapper), and `mkNixosSystem` calls our patcher instead of `nixpkgs-patcher.lib.nixosSystem`.

**Step 1: Replace the file contents**

```nix
# modules/extra/flake-parts/nixos-hosts.nix
let
  patcher = import ./patcher.nix;
in
{
  self,
  inputs,
  lib,
  withSystem,
  config,
  ...
}: {
  options = {
    nixos-hosts = {
      hosts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            system = lib.mkOption {
              type = lib.types.str;
              description = "The system architecture (e.g., x86_64-linux)";
            };

            modules = lib.mkOption {
              type = lib.types.listOf lib.types.deferredModule;
              default = [];
              description = "NixOS modules to include for this host";
            };
          };
        });
        default = {};
        description = "Host configurations to build";
      };

      sharedModules = lib.mkOption {
        type = lib.types.listOf lib.types.deferredModule;
        default = [];
        description = "Modules shared across all hosts";
      };
    };
  };

  config =
    let
      cfg = config.nixos-hosts;

      mkNixosSystem = _hostname: hostConfig:
        let
          system = hostConfig.system;

          # Unpatched pkgs — used only to run applyPatches itself.
          pkgs = import inputs.nixpkgs { inherit system; };

          # nixpkgs patching
          nixpkgsPatches = patcher.patchesFromInputs {
            inherit inputs pkgs;
            prefix = "nixpkgs-patch-";
          };
          patchedNixpkgs =
            if nixpkgsPatches == []
            then inputs.nixpkgs
            else patcher.patchSource {
              src  = inputs.nixpkgs;
              name = "nixpkgs-${patcher.nixpkgsVersion {
                nixpkgs = inputs.nixpkgs;
                patches = nixpkgsPatches;
              }}";
              patches = nixpkgsPatches;
              inherit pkgs;
            };

          # home-manager patching
          hmPatches = patcher.patchesFromInputs {
            inherit inputs pkgs;
            prefix = "home-manager-patch-";
          };
          patchedHm =
            if hmPatches == []
            then inputs.home-manager
            else patcher.patchSource {
              src     = inputs.home-manager;
              name    = "home-manager-patched";
              patches = hmPatches;
              inherit pkgs;
            };

          # Metadata module: marks nixos-version as patched when nixpkgs is patched.
          versionModules = lib.optional (nixpkgsPatches != []) {
            config.nixpkgs.flake.source       = toString inputs.nixpkgs;
            config.system.nixos.versionSuffix = ".${patcher.nixpkgsVersion {
              nixpkgs = inputs.nixpkgs;
              patches = nixpkgsPatches;
            }}";
            config.system.nixos.revision = inputs.nixpkgs.rev or "dirty";
          };
        in
          import "${patchedNixpkgs}/nixos/lib/eval-config.nix" {
            inherit system;
            specialArgs = { inherit inputs self; };
            modules =
              cfg.sharedModules
              ++ hostConfig.modules
              ++ [
                { nixpkgs.overlays = [ self.overlays.localPackages ]; }
                {
                  _module.args = withSystem system (
                    { self', inputs', ... }: { inherit self' inputs'; }
                  );
                }
                # home-manager NixOS module — from patched source if patches present
                "${patchedHm}/nixos"
              ]
              ++ versionModules;
          };
    in
    {
      flake.nixosConfigurations = lib.mapAttrs mkNixosSystem cfg.hosts;
    };
}
```

**Step 2: Verify evaluation (fast check, no build)**

Run: `nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath`

Expected: a `/nix/store/…-nixos-system-hyperion-*.drv` path (no errors).

**Step 3: Commit**

```bash
git add modules/extra/flake-parts/nixos-hosts.nix
git commit -m "Rewrite nixos-hosts.nix to use in-repo patcher, add home-manager patching"
```

---

### Task 3: Remove HM NixOS module from `systems/default.nix`

**Files:**
- Modify: `systems/default.nix:13`

**Context:** `nixos-hosts.nix` now injects `"${patchedHm}/nixos"` directly, so the hardwired `inputs.home-manager.nixosModules.home-manager` entry in `sharedModules` must go — otherwise home-manager is imported twice.

**Step 1: Delete line 13**

Remove this line from the `sharedModules` list:
```nix
      inputs.home-manager.nixosModules.home-manager
```

**Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath`

Expected: same store path as after Task 2 (or a new valid drv — the important thing is no errors).

**Step 3: Commit**

```bash
git add systems/default.nix
git commit -m "Remove redundant home-manager NixOS module from sharedModules (now in nixos-hosts.nix)"
```

---

### Task 4: Simplify `flake/systems.nix`

**Files:**
- Modify: `flake/systems.nix`

**Context:** `nixos-hosts.nix` is no longer a curried function, so the `(import … { inherit (inputs) nixpkgs-patcher; })` wrapper becomes a plain path import.

**Step 1: Replace file contents**

```nix
{inputs, ...}: {
  imports = [
    inputs.home-manager.flakeModules.home-manager
    ../modules/extra/flake-parts/nixos-hosts.nix
    ../systems
  ];
}
```

**Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath`

Expected: valid drv path.

**Step 3: Commit**

```bash
git add flake/systems.nix
git commit -m "Simplify flake/systems.nix: nixos-hosts.nix no longer needs nixpkgs-patcher arg"
```

---

### Task 5: Remove `nixpkgs-patcher` from `flake.nix` and update lock

**Files:**
- Modify: `flake.nix:23` (remove the `nixpkgs-patcher` input line)

**Step 1: Delete the input**

Remove this line from `flake.nix`:
```nix
    nixpkgs-patcher.url = "github:gepbird/nixpkgs-patcher";
```

**Step 2: Update flake.lock**

Run: `nix flake lock`

This removes the `nixpkgs-patcher` entry (and any transitive inputs it brought in) from `flake.lock`.

**Step 3: Final evaluation check across all hosts**

Run all three in sequence, verifying each returns a valid drv path:
```bash
nix eval .#nixosConfigurations.hyperion.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.iserlohn.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.ulysses.config.system.build.toplevel.drvPath
```

**Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "Remove nixpkgs-patcher input, replaced by in-repo patcher"
```

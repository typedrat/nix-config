# In-Repo Patcher: nixpkgs + home-manager

**Date:** 2026-03-02

## Goal

Replace the `nixpkgs-patcher` flake input with an equivalent implementation inlined into
`modules/extra/flake-parts/`, extended to also support patching the `home-manager` source
via `home-manager-patch-*` flake inputs.

## Design

### New file: `modules/extra/flake-parts/patcher.nix`

A plain Nix file (not a flake-parts module) imported with `import`. Exposes:

- **`patchesFromInputs { inputs, pkgs, prefix }`**
  Filters flake inputs whose names start with `prefix`, wraps each in a
  `stdenvNoCC.mkDerivation` to give it a stable name (same technique as nixpkgs-patcher).

- **`patchSource { src, name, patches, pkgs }`**
  Calls `pkgs.applyPatches` with nixpkgs-patcher's `bat`-based `failureHook` for good DX.
  Returns the patched source path. Only called when `patches != []`.

### Changes to `nixos-hosts.nix`

- Remove the `nixpkgs-patcher` parameter.
- Import `patcher.nix` at the top of the file.
- In `mkNixosSystem`:
  1. Bootstrap `pkgs` from **unpatched** `inputs.nixpkgs` + `hostConfig.system`.
  2. Collect nixpkgs patches via `patchesFromInputs` with prefix `"nixpkgs-patch-"`.
  3. Collect home-manager patches via `patchesFromInputs` with prefix `"home-manager-patch-"`.
  4. Produce `patchedNixpkgs` and `patchedHm` (skipping `patchSource` if no patches for each).
  5. Use `import "${patchedNixpkgs}/nixos/lib/eval-config.nix"` directly.
  6. Inject `"${patchedHm}/nixos"` into the modules list as the home-manager NixOS module.
  7. When nixpkgs patches are present, inject a metadata NixOS module:
     ```nix
     {
       config.nixpkgs.flake.source = toString inputs.nixpkgs;
       config.system.nixos.versionSuffix = ".${date}.${shortRev}-patched";
       config.system.nixos.revision = inputs.nixpkgs.rev or "dirty";
     }
     ```

### Changes to `systems/default.nix`

- Remove `inputs.home-manager.nixosModules.home-manager` from `sharedModules`
  (now injected by `nixos-hosts.nix`).

### Changes to `flake/systems.nix`

- Remove `inherit (inputs) nixpkgs-patcher` from the `nixos-hosts.nix` import args.

### Changes to `flake.nix`

- Remove the `nixpkgs-patcher` input entirely.

## What is deliberately dropped from nixpkgs-patcher

- The `nixpkgs-patcher` NixOS module (`nixpkgs-patcher.settings.patches`) — never used.
- The double-evaluation pass for collecting module-defined patches — not needed without it.

## Scope notes

- `config.system.nixos.versionSuffix` patching applies to nixpkgs patches only.
  home-manager has no equivalent metadata surface.
- If `*-patch-*` inputs are absent the fast path (no `applyPatches` call) is taken,
  so there is zero overhead when no patches are active.

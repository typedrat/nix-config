# modules/extra/flake-parts/patcher.nix
#
# Drop-in replacement for the nixpkgs-patcher flake input.
# Exposes helpers to patch nixpkgs and home-manager from flake inputs
# named with a given prefix (e.g. "nixpkgs-patch-*", "home-manager-patch-*").
let
  # Give a raw patch input a usable name: flake inputs all land in the store as
  # "…-source", which says nothing in a build log. builtins.path renames the
  # file during evaluation, so patches never become derivations and never
  # acquire a platform of their own.
  namePatch = patch:
    builtins.path {
      inherit (patch) name;
      path = patch.value.outPath;
    };

  # Collect all inputs whose names start with `prefix`, in name order — stacked
  # patches rely on that, since each one's hunks assume its predecessor applied.
  patchesFromInputs = {
    inputs,
    lib,
    prefix,
  }:
    map namePatch (lib.attrsToList (lib.filterAttrs (n: _: lib.hasPrefix prefix n) inputs));

  # Apply a list of patches to a source tree using pkgs.applyPatches.
  # Provides a bat-based failure hook (same UX as nixpkgs-patcher).
  # Only call this when patches != [].
  #
  # `pkgs` decides which platform runs the patching, and is the caller's to
  # choose — the result is pure text, so it is not the platform the tree will
  # be used on. See patchedNixpkgs.buildSystem in patched-nixpkgs.nix.
  patchSource = {
    src,
    name,
    patches,
    pkgs,
  }:
    pkgs.applyPatches {
      inherit name src patches;
      nativeBuildInputs =
        [pkgs.bat]
        ++ pkgs.lib.optionals pkgs.stdenv.buildPlatform.isLinux [pkgs.breakpointHook];
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
  nixpkgsVersion = {
    nixpkgs,
    patches,
  }:
    "${builtins.substring 0 8 (nixpkgs.lastModifiedDate or "19700101")}"
    + ".${nixpkgs.shortRev or "dirty"}"
    + (
      if patches != []
      then "-patched"
      else ""
    );
in {
  inherit patchesFromInputs patchSource nixpkgsVersion;
}

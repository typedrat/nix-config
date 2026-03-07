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
      phases = ["installPhase"];
      installPhase = ''
        cp -r ${patch.value.outPath} $out
      '';
    };

  # Collect all inputs whose names start with `prefix`, wrap each one.
  patchesFromInputs = {
    inputs,
    pkgs,
    prefix,
  }: let
    matching = pkgs.lib.filterAttrs (n: _: pkgs.lib.hasPrefix prefix n) inputs;
    pairs = pkgs.lib.attrsToList matching;
  in
    map (wrapPatch pkgs) pairs;

  # Apply a list of patches to a source tree using pkgs.applyPatches.
  # Provides a bat-based failure hook (same UX as nixpkgs-patcher).
  # Only call this when patches != [].
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

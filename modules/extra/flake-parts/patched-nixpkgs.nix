# modules/extra/flake-parts/patched-nixpkgs.nix
#
# Build a per-system patched nixpkgs from inputs prefixed with `nixpkgs-patch-`
# and route flake-parts' default `pkgs` through it, so every perSystem
# consumer (legacyPackages, localPackages, devShells, formatter, etc.)
# transparently sees the patched tree.
#
# nixos-hosts.nix also consumes `patcher` directly to feed the patched
# source into eval-config.nix for NixOS systems; both paths use the same
# helper so patched-vs-unpatched can never drift.
let
  patcher = import ./patcher.nix;
in
  {
    inputs,
    lib,
    self,
    ...
  }: {
    perSystem = {system, ...}: let
      # Bootstrap an unpatched nixpkgs purely to run applyPatches.
      bootstrapPkgs = import inputs.nixpkgs {inherit system;};

      nixpkgsPatches = patcher.patchesFromInputs {
        inherit inputs;
        pkgs = bootstrapPkgs;
        prefix = "nixpkgs-patch-";
      };

      patchedNixpkgs =
        if nixpkgsPatches == []
        then inputs.nixpkgs
        else
          patcher.patchSource {
            src = inputs.nixpkgs;
            name = "nixpkgs-${patcher.nixpkgsVersion {
              inherit (inputs) nixpkgs;
              patches = nixpkgsPatches;
            }}";
            patches = nixpkgsPatches;
            pkgs = bootstrapPkgs;
          };

      patchedPkgs = import patchedNixpkgs {
        inherit system;
        # Match the NixOS host config — claude-code is unfree.
        config = {allowUnfree = true;};
        overlays = lib.attrValues (self.overlays or {});
      };
    in {
      _module.args.pkgs = lib.mkForce patchedPkgs;
    };
  }

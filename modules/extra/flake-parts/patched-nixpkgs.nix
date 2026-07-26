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
    config,
    ...
  }: {
    options.patchedNixpkgs.buildSystem = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      example = "aarch64-darwin";
      description = ''
        Platform that runs the patch application itself.

        Applying patches is an import-from-derivation, so the tree must be
        built during evaluation — including while evaluating some *other*
        system's outputs, as `nix flake show --all-systems` (and hence
        flakehub-push) does. Left to follow the target, that asks an
        x86_64-linux evaluator to produce an aarch64-darwin build, which it
        cannot.

        Cross-compilation does not help: perSystem's `system` names the target,
        and `import nixpkgs { system = <target>; }` is a *native* package set
        whose buildPlatform equals its hostPlatform, so `pkgsBuildBuild` is
        that same foreign platform. Only a set built with an explicit
        `localSystem` retargets the builder, and that means naming the
        evaluating machine — which pure flake evaluation deliberately hides
        (`builtins.currentSystem` is impure). So it is declared instead: set
        this to a platform your evaluators and CI can actually build on.

        The patched tree is pure text — a copy and `patch -p1` — so this choice
        cannot affect its contents; it only decides who does the copying, and
        every system ends up sharing the one resulting store path.
      '';
    };

    config.perSystem = {system, ...}: let
      # Bootstrap an unpatched nixpkgs purely to run applyPatches.
      bootstrapPkgs = import inputs.nixpkgs {system = config.patchedNixpkgs.buildSystem;};

      nixpkgsPatches = patcher.patchesFromInputs {
        inherit inputs lib;
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

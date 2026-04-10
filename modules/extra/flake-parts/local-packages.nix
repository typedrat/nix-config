{
  lib,
  inputs,
  config,
  ...
}: let
  inherit (lib) mkOption types;

  cfg = config.localPackages;

  # Flatten nested package sets into a flat attrset with path-based names
  flattenPkgs = path: value:
    if lib.isDerivation value
    then {
      ${lib.concatStringsSep cfg.nameSeparator path} = value;
    }
    else if lib.isAttrs value
    then lib.concatMapAttrs (name: flattenPkgs (path ++ [name])) value
    else {};

  # Extract packages from the scope, handling nested scopes
  extractPackages = scope: let
    shouldRecurse =
      lib.isAttrs scope
      && !(lib.isDerivation scope)
      && scope ? "packages"
      && lib.isFunction scope.packages;
    mappedSet = lib.mapAttrs (_: extractPackages) (scope.packages scope);
  in
    if shouldRecurse
    then mappedSet
    else scope;
in {
  options.localPackages = {
    directory = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Directory containing local package definitions following the pkgs-by-name convention.
      '';
    };

    nameSeparator = mkOption {
      type = types.str;
      default = "/";
      description = ''
        The separator to use when flattening nested package names.
      '';
    };

    packageSets = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            directory = mkOption {
              type = types.path;
              description = ''
                Directory containing package definitions for this set,
                following the pkgs-by-name convention.
              '';
            };

            callPackage = mkOption {
              type = types.functionTo (types.functionTo types.unspecified);
              description = ''
                Function that receives the final pkgs set and returns a
                callPackage function with the appropriate scope for this
                package set.

                Example: `pkgs: pkgs.home-assistant.python.pkgs.callPackage`
              '';
            };
          };
        }
      );
      default = {};
      description = ''
        Additional package sets whose packages need a specialised callPackage
        scope (e.g. ghidra-extensions, home-assistant-custom-components).
        Each entry is keyed by the attribute name in nixpkgs that the packages
        should be merged into.
      '';
    };
  };

  config = lib.mkIf (cfg.directory != null) {
    flake.overlays.localPackages = final: prev: let
      inputsScope = lib.makeScope final.newScope (_self: {
        inherit inputs;
      });
      scope = lib.filesystem.packagesFromDirectoryRecursive {
        inherit (cfg) directory;
        inherit (inputsScope) newScope callPackage;
      };

      # Discover packages for each packageSet and merge with the existing
      # nixpkgs attribute of the same name so upstream packages are preserved.
      packageSetOverlays =
        lib.mapAttrs (
          name: setCfg:
            (prev.${name} or {})
            // lib.filesystem.packagesFromDirectoryRecursive {
              callPackage = setCfg.callPackage final;
              inherit (setCfg) directory;
            }
        )
        cfg.packageSets;
    in
      extractPackages scope // packageSetOverlays;

    perSystem = {pkgs, ...}: let
      # Create a scope that includes flake inputs for packages that need them
      inputsScope = lib.makeScope pkgs.newScope (_self: {
        inherit inputs;
      });

      scope = lib.filesystem.packagesFromDirectoryRecursive {
        inherit (cfg) directory;
        inherit (inputsScope) newScope callPackage;
      };

      localPackages = extractPackages scope;
      flatPackages = flattenPkgs [] localPackages;

      # Filter packages to only include those available on the current platform
      availablePackages =
        lib.filterAttrs (
          _name: pkg: lib.meta.availableOn pkgs.stdenv.hostPlatform pkg
        )
        flatPackages;
    in {
      # Expose our packages in the standard packages output (flattened for flake compatibility)
      packages = availablePackages;

      # Expose full nixpkgs with our packages overlaid (nested structure preserved)
      legacyPackages = pkgs.appendOverlays [
        (_final: _prev: localPackages)
        (
          final: prev:
            lib.mapAttrs (
              name: setCfg:
                (prev.${name} or {})
                // lib.filesystem.packagesFromDirectoryRecursive {
                  callPackage = setCfg.callPackage final;
                  inherit (setCfg) directory;
                }
            )
            cfg.packageSets
        )
      ];
    };
  };
}

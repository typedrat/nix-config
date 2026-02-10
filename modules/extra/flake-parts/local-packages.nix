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
  };

  config = lib.mkIf (cfg.directory != null) {
    flake.overlays.localPackages = final: _prev: let
      inputsScope = lib.makeScope final.newScope (_self: {
        inherit inputs;
      });
      scope = lib.filesystem.packagesFromDirectoryRecursive {
        inherit (cfg) directory;
        inherit (inputsScope) newScope callPackage;
      };
    in
      extractPackages scope;

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
          _name: pkg:
            lib.meta.availableOn pkgs.stdenv.hostPlatform pkg
        )
        flatPackages;
    in {
      # Expose our packages in the standard packages output (flattened for flake compatibility)
      packages = availablePackages;

      # Expose full nixpkgs with our packages overlaid (nested structure preserved)
      legacyPackages = pkgs.appendOverlays [
        (_final: _prev: localPackages)
      ];
    };
  };
}

{
  lib,
  flake-parts-lib,
  inputs,
  ...
}: let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
in {
  options = {
    perSystem = mkPerSystemOption (_: {
      options = {
        localPackages = {
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
      };
    });
  };

  config = {
    perSystem = {
      config,
      pkgs,
      ...
    }: let
      cfg = config.localPackages;

      # Flatten nested package sets into a flat attrset with path-based names
      flattenPkgs = separator: path: value:
        if lib.isDerivation value
        then {
          ${lib.concatStringsSep separator path} = value;
        }
        else if lib.isAttrs value
        then lib.concatMapAttrs (name: flattenPkgs separator (path ++ [name])) value
        else {};

      # Create a scope that includes flake inputs for packages that need them
      inputsScope = lib.makeScope pkgs.newScope (_self: {
        inherit inputs;
      });

      # Load packages from directory using nixpkgs' packagesFromDirectoryRecursive
      scopeFromDirectory = directory:
        lib.filesystem.packagesFromDirectoryRecursive {
          inherit directory;
          inherit (inputsScope) newScope callPackage;
        };

      scope = scopeFromDirectory cfg.directory;

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

      localPackages = extractPackages scope;
      flatPackages = flattenPkgs cfg.nameSeparator [] localPackages;

      # Filter packages to only include those available on the current platform
      availablePackages = lib.filterAttrs (_name: pkg:
        lib.meta.availableOn pkgs.stdenv.hostPlatform pkg
      ) flatPackages;
    in
      lib.mkIf (cfg.directory != null) {
        # Expose our packages in the standard packages output (flattened for flake compatibility)
        packages = availablePackages;

        # Expose full nixpkgs with our packages overlaid (nested structure preserved)
        legacyPackages = pkgs.appendOverlays [
          (_final: _prev: localPackages)
        ];
      };
  };
}

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

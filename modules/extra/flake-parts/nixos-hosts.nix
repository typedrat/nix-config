{nixpkgs-patcher}: {
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

  config = let
    cfg = config.nixos-hosts;

    # Helper function to create a NixOS configuration with nixpkgs-patcher
    mkNixosSystem = _hostname: hostConfig:
      nixpkgs-patcher.lib.nixosSystem {
        inherit (hostConfig) system;

        # Pass inputs and self via specialArgs (same as easy-hosts did)
        specialArgs = {
          inherit inputs self;
        };

        modules =
          cfg.sharedModules
          ++ hostConfig.modules
          ++ [
            # Module to provide self' and inputs' using withSystem
            {
              _module.args = withSystem hostConfig.system ({
                self',
                inputs',
                ...
              }: {
                inherit self' inputs';
              });
            }
          ];

        # Pass inputs via nixpkgsPatcher for patch discovery
        nixpkgsPatcher.inputs = inputs;
      };
  in {
    flake.nixosConfigurations = lib.mapAttrs mkNixosSystem cfg.hosts;
  };
}

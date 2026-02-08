{
  self,
  inputs,
  withSystem,
  ...
}: {
  flake = {
    lib = import ../lib {
      inherit inputs;
      inherit (inputs.nixpkgs) lib;
    };

    nixosModules = {
      ensure-pcr = {imports = [../modules/extra/nixos/ensure-pcr.nix];};
      port-magic = {imports = [../modules/extra/nixos/port-magic];};
      servarr-multitenant = {imports = [../modules/extra/nixos/servarr-multitenant];};
    };

    # Minimal air-gapped live environment for security key generation
    # Build ISO with: nix build .#nixosConfigurations.keygen-live.config.system.build.isoImage
    nixosConfigurations.keygen-live = withSystem "x86_64-linux" ({self', ...}:
      inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ../systems/keygen-live
          {_module.args = {inherit self';};}
        ];
      });

    homeModules = {
      skyscraper = {imports = [../modules/extra/home-manager/skyscraper];};
    };

    hydraJobs = {
      nodes = builtins.mapAttrs (_: node: node.config.system.build.toplevel) self.nixosConfigurations;
    };
  };
}

{
  self,
  inputs,
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

    hydraJobs = {
      nodes = builtins.mapAttrs (_: node: node.config.system.build.toplevel) self.nixosConfigurations;
    };
  };
}

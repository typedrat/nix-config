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

    overlays.nix-output-monitor = _final: prev: {
      # Determinate Nix 3.23 emits activity type 10113, which nom rejects as a
      # JSON parse error (maralorn/nix-output-monitor#320)
      nix-output-monitor = prev.nix-output-monitor.overrideAttrs (old: {
        # The diff is rooted at the repo, but the package builds from its
        # nix-output-monitor/ subdirectory.
        patchFlags = ["-p2"];
        patches =
          (old.patches or [])
          ++ [
            (prev.fetchurl {
              url = "https://github.com/maralorn/nix-output-monitor/pull/321.diff";
              hash = "sha256-YXpElsb9i1k2Bf52IYmSU9CQJNMMwH0XuJkXHkpmzDY=";
            })
          ];
      });
    };

    nixosModules = {
      ensure-pcr = {imports = [../modules/extra/nixos/ensure-pcr.nix];};
      port-magic = {imports = [../modules/extra/nixos/port-magic];};
      servarr-multitenant = {imports = [../modules/extra/nixos/servarr-multitenant];};
    };

    # Minimal air-gapped live environment for security key generation
    # Build ISO with: nix build .#nixosConfigurations.keygen-live.config.system.build.isoImage
    nixosConfigurations.keygen-live = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ../systems/keygen-live
        {nixpkgs.overlays = [self.overlays.localPackages];}
      ];
    };

    homeModules = {
      skyscraper = {imports = [../modules/extra/home-manager/skyscraper];};
    };

    hydraJobs = {
      nodes = builtins.mapAttrs (_: node: node.config.system.build.toplevel) self.nixosConfigurations;
    };
  };
}

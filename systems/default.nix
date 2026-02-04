{
  self,
  inputs,
  ...
}: {
  nixos-hosts = {
    # Shared modules across all NixOS systems
    sharedModules = [
      "${self}/modules/nixos"
      "${self}/modules/shared"
      "${self}/users"
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      (
        {
          self',
          inputs',
          ...
        }: {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";

            extraSpecialArgs = {
              inherit self self' inputs inputs';
            };

            sharedModules = [
              "${self}/modules/home-manager"
              "${self}/modules/extra/home-manager/comfy-cli.nix"
            ];
          };
        }
      )
      # Auto-configure home-manager for enabled rat.users only
      (
        {
          lib,
          config,
          ...
        }: let
          enabledUsers = lib.filterAttrs (_: userCfg: userCfg.enable) config.rat.users;
        in {
          config.home-manager.users = lib.mkMerge (
            lib.mapAttrsToList
            (username: _: {${username} = {imports = [];};})
            enabledUsers
          );
        }
      )
    ];

    # Host configurations
    hosts = {
      hyperion = {
        system = "x86_64-linux";
        modules = [./hyperion];
      };

      iserlohn = {
        system = "x86_64-linux";
        modules = [./iserlohn];
      };

      ulysses = {
        system = "x86_64-linux";
        modules = [./ulysses];
      };
    };
  };
}

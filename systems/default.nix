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
            backupFileExtension = ".backup";

            extraSpecialArgs = {
              inherit self self' inputs inputs';
            };

            sharedModules = [
              "${self}/modules/home-manager"
            ];
          };
        }
      )
      # Auto-configure home-manager for all rat.users
      (
        {
          lib,
          config,
          ...
        }: {
          config.home-manager.users = lib.mkMerge (
            lib.mapAttrsToList
            (username: _: {${username} = {imports = [];};})
            config.rat.users
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
    };
  };
}

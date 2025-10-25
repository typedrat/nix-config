{self, inputs, ...}: {
  nixos-hosts = {
    # Shared modules across all NixOS systems
    sharedModules = [
      ../users
      "${self}/modules/nixos"
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
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

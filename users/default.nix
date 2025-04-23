{
  pkgs,
  self,
  self',
  inputs,
  inputs',
  ...
}: {
  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      extraSpecialArgs = {
        inherit
          self
          self'
          inputs
          inputs'
          ;
      };

      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.catppuccin.homeModules.catppuccin
        inputs.spicetify-nix.homeManagerModules.default
        inputs.wayland-pipewire-idle-inhibit.homeModules.default
        self.homeModules.zen-browser

        {
          home.stateVersion = "25.05";
        }
      ];

      users.awilliams = ./awilliams;
    };

    users.users.awilliams = {
      uid = 1000;
      isNormalUser = true;
      home = "/home/awilliams";
      extraGroups = ["games" "wheel"];
      shell = pkgs.zsh;
    };
  };
}

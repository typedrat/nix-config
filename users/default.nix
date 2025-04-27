{
  config,
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
        {
          home.stateVersion = "25.05";
        }
      ];

      users.awilliams = ./awilliams;
    };

    users = {
      # mutableUsers = false;

      users.root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFCm+qnsWUuTDU6IgvxPAkfe6dnwwomGQXlM9c2yUqlJ"
        ];
        hashedPasswordFile = config.sops.secrets."users/root/hashedPassword".path;
      };

      users.awilliams = {
        uid = 1000;
        isNormalUser = true;
        home = "/home/awilliams";
        extraGroups = ["games" "wheel"];
        shell = pkgs.zsh;

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFCm+qnsWUuTDU6IgvxPAkfe6dnwwomGQXlM9c2yUqlJ"
        ];
        hashedPasswordFile = config.sops.secrets."users/awilliams/hashedPassword".path;
      };
    };
  };
}

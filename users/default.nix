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
      backupFileExtension = ".backup";

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

      users.awilliams = {
        uid = 1000;
        isNormalUser = true;
        home = "/home/awilliams";
        extraGroups =
          [
            "dialout"
            "games"
            "wheel"
          ]
          ++ (
            if config.rat.virtualisation.libvirt.enable
            then ["libvirtd"]
            else []
          );
        shell = pkgs.zsh;

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFCm+qnsWUuTDU6IgvxPAkfe6dnwwomGQXlM9c2yUqlJ awilliams@hyperion"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjz3PWnehAKNKXGpkDu+Huiyizd/24efmLmJCoct+KP awilliams@hyperion-windows"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLI5a9axsIGCRFLzb9lviLINzebCWV68O94WlXRnMkEKO8uqLAJHGy2aw8i/rB4TcLfqP5lBvOZn0nCNRTvZIRg= awilliams@ipad"
        ];
        hashedPasswordFile = config.sops.secrets."users/awilliams/hashedPassword".path;
      };
    };
  };
}

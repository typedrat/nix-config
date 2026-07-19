{
  imports = [
    ./traefik
    ./acme.nix
    ./authentik.nix
    ./backup.nix
    ./librespeed.nix
    ./monitor.nix
    ./mysql.nix
    ./postgres.nix
  ];
}

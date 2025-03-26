{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.nix-alien.packages.${pkgs.stdenv.system}.nix-alien
  ];

  programs.nix-ld.enable = true;
}

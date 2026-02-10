{
  imports = [
    ../modules/extra/flake-parts/local-packages.nix
  ];

  localPackages.directory = ../packages;
}

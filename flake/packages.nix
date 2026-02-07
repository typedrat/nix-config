{
  imports = [
    ../modules/extra/flake-parts/local-packages.nix
  ];

  perSystem = {
    localPackages.directory = ../packages;
  };
}

{
  imports = [
    ../modules/extra/flake-parts/local-packages.nix
  ];

  localPackages.directory = ../packages;

  localPackages.packageSets = {
    ghidra-extensions = {
      directory = ../packagesets/ghidra-extensions;
      callPackage = pkgs: pkgs.ghidra-extensions.callPackage;
    };
  };
}

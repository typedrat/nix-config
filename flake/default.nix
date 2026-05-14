{
  imports = [
    ../modules/extra/flake-parts/patched-nixpkgs.nix

    ./github-actions
    ./devshell.nix
    ./formatter.nix
    ./outputs.nix
    ./packages.nix
    ./rebuild.nix
    ./systems.nix
    ./terranix.nix
  ];
}

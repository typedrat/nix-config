{inputs, ...}: {
  imports = [
    inputs.home-manager.flakeModules.home-manager

    ../modules/extra/flake-parts/nixos-hosts.nix

    ../systems
  ];
}

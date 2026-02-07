{inputs, ...}: {
  imports = [
    inputs.home-manager.flakeModules.home-manager

    (import ../modules/extra/flake-parts/nixos-hosts.nix {
      inherit (inputs) nixpkgs-patcher;
    })

    ../systems
  ];
}

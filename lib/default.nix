{lib, ...}: let
  inherit (import ./umport.nix {inherit lib;}) umport;
in {
  imports = umport {
    path = ./.;
    exclude = [
      ./default.nix
      ./umport.nix
    ];
  };

  inherit umport;
}

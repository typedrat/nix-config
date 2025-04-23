{lib, ...}: let
  inherit (lib.options) mkEnableOption;
in {
  imports = [
    ./greetd.nix
    ./hyprland.nix
    ./plymouth.nix
  ];

  options.rat = {
    gui.enable = mkEnableOption "gui";
  };
}

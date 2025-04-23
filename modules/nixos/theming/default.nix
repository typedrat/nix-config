{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
in {
  imports = [
    inputs.catppuccin.nixosModules.default

    ./fonts.nix
  ];

  options.rat = {
    theming.enable =
      mkEnableOption "theming"
      // {
        default = true;
      };
  };

  config = {
    catppuccin = {
      flavor = lib.mkDefault "frappe";
      accent = lib.mkDefault "lavender";

      tty.enable = true;
      plymouth.enable = config.rat.gui.plymouth.enable;
    };
  };
}

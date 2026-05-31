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
      # catppuccin/nix is moving to an explicit autoEnable model. Setting both
      # `enable` and `autoEnable` to true preserves the previous behavior (all
      # ports auto-enrolled) and silences the migration warning.
      enable = true;
      autoEnable = true;

      flavor = lib.mkDefault "frappe";
      accent = lib.mkDefault "lavender";

      tty.enable = true;
      plymouth.enable = config.rat.gui.plymouth.enable;
      limine.enable = config.rat.boot.loader == "limine";
    };
  };
}

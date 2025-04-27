{
  osConfig,
  inputs,
  inputs',
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    programs.spicetify = {
      enable = true;

      theme = inputs'.spicetify-nix.legacyPackages.themes.catppuccin;
      colorScheme = osConfig.catppuccin.flavor;
    };
  };
}

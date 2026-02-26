{
  osConfig,
  inputs,
  inputs',
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/spotify"];
    };

    programs.spicetify = {
      enable = true;

      theme = inputs'.spicetify-nix.legacyPackages.themes.catppuccin;
      colorScheme = osConfig.catppuccin.flavor;
    };
  };
}

{
  osConfig,
  inputs,
  inputs',
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir cacheRoot;
in {
  imports = [
    inputs.spicetify-nix.homeManagerModules.default
  ];

  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.media.enable) {
    home.persistence = mkIf impermanenceCfg.home.enable (lib.modules.mkMerge [
      {
        ${persistDir} = {
          directories = [".config/spotify"];
        };
      }
      {${cacheRoot}.directories = [".cache/spotify"];}
    ]);

    programs.spicetify = {
      enable = true;

      theme = inputs'.spicetify-nix.legacyPackages.themes.catppuccin;
      colorScheme = osConfig.catppuccin.flavor;
    };
  };
}

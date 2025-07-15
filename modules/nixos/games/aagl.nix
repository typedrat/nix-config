{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
in {
  imports = [
    inputs.anime-game-launcher.nixosModules.default
  ];

  options.rat.games.animeGameLaunchers.enable = mkEnableOption "anime game launchers";

  config = mkMerge [
    {
      nix.settings = inputs.anime-game-launcher.nixConfig;

      aagl.enableNixpkgsReleaseBranchCheck = false;
    }
    (mkIf (config.rat.games.enable && config.rat.games.animeGameLaunchers.enable) {
      programs.anime-game-launcher.enable = true;
      programs.honkers-railway-launcher.enable = true;
      programs.sleepy-launcher.enable = true;
    })
  ];
}

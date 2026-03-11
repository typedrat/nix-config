{
  osConfig,
  lib,
  ...
}: let
  inherit (lib) modules;
  aaglCfg = osConfig.rat.gaming.animeGameLaunchers;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (osConfig.rat.gaming.enable && aaglCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/anime-game-launcher"
        ".local/share/honkers-railway-launcher"
        ".local/share/sleepy-launcher"
      ];
    };
  };
}

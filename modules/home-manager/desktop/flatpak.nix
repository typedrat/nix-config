{
  osConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = mkIf osConfig.rat.flatpak.enable {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [
        # Per-app sandbox data (settings, caches, saves)
        ".var/app"
        # User-installed flatpaks and remote configuration
        ".local/share/flatpak"
      ];
    };
  };
}

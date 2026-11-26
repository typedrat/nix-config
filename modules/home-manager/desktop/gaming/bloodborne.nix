{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  guiCfg = userCfg.gui or {};
  gamingCfg = guiCfg.gaming or {};
  bloodborneCfg = gamingCfg.bloodborne or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && bloodborneCfg.enable) {
    home.packages = [
      (pkgs.bloodborne-pc.override {pathTracing = bloodborneCfg.pathTracing.enable;})
    ];

    # Saves, DLC entitlement, shader/RT caches and settings. The 30 GB game
    # dump stays in ~/Games/Bloodborne (persisted by the gaming module).
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/bloodborne-pc"
        ".config/bloodborne-pc"
        # The launcher's own settings, including the SuperMedo sign-in
        ".config/bbport-launcher"
      ];
    };
  };
}

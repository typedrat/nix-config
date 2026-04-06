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
  productivityCfg = guiCfg.productivity or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;
in {
  config = modules.mkIf (guiCfg.enable && productivityCfg.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [".config/kicad" ".local/share/kicad"];
    };

    home.packages = [
      (pkgs.kicad.override {
        addons = with pkgs.kicadAddons; [
          # TODO: re-enable once upstream adds KiCAD 10 compatibility
          # kikit
          # kikit-library
        ];
      })
    ];
  };
}

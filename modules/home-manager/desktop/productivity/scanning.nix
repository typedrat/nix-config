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

  # skanpage's default override asks tesseract for an empty language set, which
  # builds the engine with no traineddata and leaves OCR permanently disabled.
  # jpn_vert is a separate model from jpn and is the one that reads tategaki.
  skanpage = pkgs.kdePackages.skanpage.override {
    tesseractLanguages = [
      "eng"
      "jpn"
      "jpn_vert"
    ];
  };
in {
  config =
    modules.mkIf (
      guiCfg.enable
      && productivityCfg.enable
      && (productivityCfg.scanning.enable or false)
      && osConfig.rat.hardware.scanning.enable
    ) {
      home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
        files = [".config/skanpagerc"];
      };

      home.packages = [skanpage];
    };
}

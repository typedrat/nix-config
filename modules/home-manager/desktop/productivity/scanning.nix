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
  skanpageWithOcr = pkgs.kdePackages.skanpage.override {
    tesseractLanguages = [
      "eng"
      "jpn"
      "jpn_vert"
    ];
  };

  # QT_STYLE_OVERRIDE names a QWidget style, but Qt also feeds it to QtQuick
  # Controls style resolution, so a pure-QML app goes looking for a QML module
  # called "kvantum", finds nothing, and dies before it draws a window. Nothing
  # is lost by dropping it here: skanpage has no QWidget UI for Kvantum to skin.
  skanpage = pkgs.symlinkJoin {
    name = "skanpage-${skanpageWithOcr.version}";
    paths = [skanpageWithOcr];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/skanpage --unset QT_STYLE_OVERRIDE
    '';
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

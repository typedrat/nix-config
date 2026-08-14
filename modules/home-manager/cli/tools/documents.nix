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
  cliCfg = userCfg.cli or {};
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.tools.enable) {
    home.packages = with pkgs; [
      # Adds a text layer to scanned PDFs that have none. Ghostscript is
      # deliberately not installed alongside it: ocrmypdf patches in absolute
      # store paths for gs, tesseract and unpaper, and ghostscript's `gs`
      # would collide with git-spice's binary of the same name.
      ocrmypdf
      # `mutool draw -F txt` keeps reading order better than pdftotext on
      # multi-column layouts, and `mutool extract` pulls embedded assets.
      mupdf-headless
      poppler-utils
      qpdf
    ];
  };
}

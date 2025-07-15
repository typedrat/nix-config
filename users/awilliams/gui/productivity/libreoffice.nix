{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.packages = with pkgs; [
      libreoffice-qt6
      hunspell
      hunspellDicts.en_US-large
    ];
  };
}

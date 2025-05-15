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
      (kicad.override {
        addons = with pkgs.kicadAddons; [
          kikit
          kikit-library
        ];
      })
    ];
  };
}

{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;

  wrapJetbrains = pkg:
    pkg.override {
      vmopts = "-Dawt.toolkit.name=WLToolkit";
    };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.devtools.enable) {
    home.packages = builtins.map wrapJetbrains (with pkgs.jetbrains; [
      datagrip
      webstorm
    ]);
  };
}

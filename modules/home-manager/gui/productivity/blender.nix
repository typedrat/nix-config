{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.modules) mkIf;
  rocmEnabled = pkgs.config.rocmSupport or false;
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.productivity.enable) {
    home.packages = with pkgs; [
      (blender.override
        (optionalAttrs rocmEnabled {hipSupport = true;}))
    ];
  };
}

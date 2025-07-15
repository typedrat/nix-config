{
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  
  themesDir = "${inputs.catppuccin-imhex}/themes";
  themeFiles = 
    builtins.filter
    (file: lib.hasSuffix ".json" file)
    (lib.filesystem.listFilesRecursive themesDir);
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.devtools.enable) {
    home.packages = with pkgs; [
      imhex
    ];
    
    xdg.dataFile = lib.listToAttrs (map
      (file: {
        name = builtins.unsafeDiscardStringContext "imhex/themes/${baseNameOf file}";
        value = {source = file;};
      })
      themeFiles);
  };
}

{
  inputs,
  pkgs,
  lib,
  ...
}: let
  themesDir = "${inputs.catppuccin-tauon-music-box}/themes";
  themeFiles =
    builtins.filter
    (file: lib.hasSuffix ".ttheme" file)
    (lib.filesystem.listFilesRecursive themesDir);
in {
  home.packages = with pkgs; [
    tauon
  ];

  xdg.dataFile = lib.listToAttrs (map
    (file: {
      name = builtins.unsafeDiscardStringContext "TauonMusicBox/theme/${baseNameOf file}";
      value = {source = file;};
    })
    themeFiles);
}

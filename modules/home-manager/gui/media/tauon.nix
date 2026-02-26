{
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  themesDir = "${inputs.catppuccin-tauon-music-box}/themes";
  themeFiles =
    builtins.filter
    (file: lib.hasSuffix ".ttheme" file)
    (lib.filesystem.listFilesRecursive themesDir);
in {
  home.persistence.${persistDir} = mkIf impermanenceCfg.enable {
    directories = [".local/share/TauonMusicBox"];
  };

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

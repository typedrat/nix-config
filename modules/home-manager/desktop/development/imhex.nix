{
  osConfig,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  themesDir = "${inputs.catppuccin-imhex}/themes";
  themeFiles =
    builtins.filter
    (file: lib.hasSuffix ".json" file)
    (lib.filesystem.listFilesRecursive themesDir);
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.development.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [".config/imhex" ".local/share/imhex"];
    };

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

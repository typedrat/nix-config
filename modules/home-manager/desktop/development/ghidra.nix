{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  ghidraWithExtensions = pkgs.ghidra.withExtensions (_: [
    pkgs.ghidra-extensions.reverse-engineering-assistant
  ]);

  ghidraWrapped = pkgs.symlinkJoin {
    name = "ghidra-wrapped";
    paths = [ghidraWithExtensions];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      wrapProgram "$out/bin/ghidra" \
        --set _JAVA_AWT_WM_NONREPARENTING 1 \
        --set JAVA_HOME "${pkgs.jre}"
    '';
  };
in {
  config = mkIf (osConfig.rat.gui.enable && osConfig.rat.gui.development.enable) {
    home.persistence.${persistDir} = mkIf impermanenceCfg.home.enable {
      directories = [
        ".cache/ghidra"
        ".config/ghidra"
      ];
    };

    home.packages = [ghidraWrapped];
  };
}

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
    pkgs.ghidra-extensions.ghidra-snes
    pkgs.ghidra-extensions.ghidra-boy
  ]);

  # tkinter is only for pyghidraw's usage/error dialogs.
  pyghidraEnv = pkgs.python3.withPackages (ps: [ps.pyghidra ps.tkinter]);

  ghidraWrapped = pkgs.symlinkJoin {
    name = "ghidra-wrapped";
    paths = [ghidraWithExtensions];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      wrapProgram "$out/bin/ghidra" \
        --set _JAVA_AWT_WM_NONREPARENTING 1 \
        --set JAVA_HOME "${pkgs.jre}"

      # pyghidra boots Ghidra in-process through JPype, so it needs the real
      # install dir for launch.properties, and NIX_GHIDRAHOME for the JVM to
      # pick up the extensions.
      for prog in pyghidra pyghidraw; do
        makeWrapper "${pyghidraEnv}/bin/$prog" "$out/bin/$prog" \
          --set GHIDRA_INSTALL_DIR "${pkgs.ghidra}/lib/ghidra" \
          --set NIX_GHIDRAHOME "${ghidraWithExtensions}/lib/ghidra/Ghidra" \
          --set _JAVA_AWT_WM_NONREPARENTING 1 \
          --set JAVA_HOME "${pkgs.jre}"
      done
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

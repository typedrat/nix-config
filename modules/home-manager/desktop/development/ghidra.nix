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
  pyghidraEnv = pkgs.python3.withPackages (ps: [
    (ps.pyghidra.overridePythonAttrs (old: {
      # Keep GUI windows' X11 class as ghidra-Ghidra instead of java-lang-Thread.
      patches = (old.patches or []) ++ [./pyghidra-x11-wm-class.patch];
    }))
    ps.tkinter
  ]);

  ghidraWrapped = pkgs.symlinkJoin {
    name = "ghidra-wrapped";
    paths = [ghidraWithExtensions];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      wrapProgram "$out/bin/ghidra" \
        --set _JAVA_AWT_WM_NONREPARENTING 1 \
        --set JAVA_HOME "${pkgs.jre}"

      # These boot Ghidra in-process through pyghidra/JPype, so they need the
      # real install dir for launch.properties, and NIX_GHIDRAHOME for the JVM
      # to pick up the extensions.
      for prog in \
        ${pyghidraEnv}/bin/pyghidra \
        ${pyghidraEnv}/bin/pyghidraw \
        ${lib.getExe pkgs.ghidra-extensions.reverse-engineering-assistant.python-wrapper}
      do
        makeWrapper "$prog" "$out/bin/$(basename "$prog")" \
          --set GHIDRA_INSTALL_DIR "${pkgs.ghidra}/lib/ghidra" \
          --set NIX_GHIDRAHOME "${ghidraWithExtensions}/lib/ghidra/Ghidra" \
          --set _JAVA_AWT_WM_NONREPARENTING 1 \
          --set JAVA_HOME "${pkgs.jre}"
      done
      ln -s pyghidraw "$out/bin/pyghidra-gui"

      # Launch from the desktop with PyGhidra so the GUI has a Python
      # interpreter. share/ is a symlink into the ghidra package, so rebuild it.
      rm "$out/share"
      mkdir -p "$out/share/applications"
      ln -s "${pkgs.ghidra}/share/icons" "$out/share/icons"
      sed 's/^Exec=ghidra$/Exec=pyghidraw/' \
        "${pkgs.ghidra}/share/applications/ghidra.desktop" \
        > "$out/share/applications/ghidra.desktop"
      grep -qx 'Exec=pyghidraw' "$out/share/applications/ghidra.desktop"
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

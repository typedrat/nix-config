{
  osConfig,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Ghidra resolves its install root and each manual's directory through
  # canonical paths, so the manuals can't be layered on with symlinks; it
  # needs a real copy of the tree. The PDFs themselves can stay links.
  ghidra = pkgs.runCommand "ghidra-with-manuals-${pkgs.ghidra.version}" {inherit (pkgs.ghidra) pname version meta;} ''
    cp -r ${pkgs.ghidra} $out
    chmod -R u+w $out
    cd ${pkgs.ghidra-processor-manuals}/lib/ghidra
    for manual in Ghidra/Processors/*/data/manuals/*; do
      if [ ! -d "$out/lib/ghidra/$(dirname "$manual")" ]; then
        echo "Ghidra has no $(dirname "$manual")" >&2
        exit 1
      fi
      ln -s "$(readlink "$manual")" "$out/lib/ghidra/$manual"
    done
  '';

  withExtensions =
    pkgs.callPackage
    (pkgs.path + "/pkgs/tools/security/ghidra/with-extensions.nix")
    {inherit ghidra;};

  ghidraWithExtensions = withExtensions (_: [
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
          --set GHIDRA_INSTALL_DIR "${ghidra}/lib/ghidra" \
          --set NIX_GHIDRAHOME "${ghidraWithExtensions}/lib/ghidra/Ghidra" \
          --set _JAVA_AWT_WM_NONREPARENTING 1 \
          --set JAVA_HOME "${pkgs.jre}"
      done
      ln -s pyghidraw "$out/bin/pyghidra-gui"

      # Launch from the desktop with PyGhidra so the GUI has a Python
      # interpreter, and let launchers find it by that name too. share/ is a
      # symlink into the ghidra package, so rebuild it.
      rm "$out/share"
      mkdir -p "$out/share/applications"
      ln -s "${ghidra}/share/icons" "$out/share/icons"
      sed 's/^Exec=ghidra$/Exec=pyghidraw\nKeywords=pyghidra;/' \
        "${ghidra}/share/applications/ghidra.desktop" \
        > "$out/share/applications/ghidra.desktop"
      grep -qx 'Exec=pyghidraw' "$out/share/applications/ghidra.desktop"
      grep -qx 'Keywords=pyghidra;' "$out/share/applications/ghidra.desktop"
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

    # Wins over the scripting Python's own bin/pyghidra, which lacks the env.
    home.packages = [(lib.hiPrio ghidraWrapped)];

    rat.python.packages = ps: [
      ps.pyghidra
      pkgs.ghidra-stubs
      pkgs.java-stubs-converted-strings
    ];

    # For `import pyghidra` from the scripting Python. JAVA_HOME_OVERRIDE pins
    # pyghidra's JVM without disturbing JAVA_HOME for everything else.
    home.sessionVariables = {
      GHIDRA_INSTALL_DIR = "${ghidra}/lib/ghidra";
      NIX_GHIDRAHOME = "${ghidraWithExtensions}/lib/ghidra/Ghidra";
      JAVA_HOME_OVERRIDE = "${pkgs.jre}";
    };
  };
}

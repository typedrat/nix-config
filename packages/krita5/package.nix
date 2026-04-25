# Krita 5.3 (Qt5 build of 6.0.x) wrapper package.
# Built with Qt5 for krita-ai-diffusion and krita-vision-tools compatibility.
{
  lib,
  libsForQt5,
  symlinkJoin,
}: let
  unwrapped = libsForQt5.callPackage ./generic.nix {};

  # Krita "5.3" is the Qt5 build of the 6.0.x codebase.
  # Rewrite the upstream version so the package reflects the Qt5 identity:
  #   6.0.x.y -> 5.3.x.y
  #   6.0.x   -> 5.3.x
  qt5Version = lib.replaceStrings ["6.0."] ["5.3."] unwrapped.version;
in
  symlinkJoin {
    name = "krita5-${qt5Version}";
    version = qt5Version;
    inherit
      (unwrapped)
      buildInputs
      nativeBuildInputs
      meta
      ;

    paths = [unwrapped];

    postBuild = ''
      wrapQtApp "$out/bin/krita" \
        --prefix PYTHONPATH : "$PYTHONPATH" \
        --set KRITA_PLUGIN_PATH "$out/lib/kritaplugins"
    '';

    passthru = {
      inherit unwrapped;
    };
  }

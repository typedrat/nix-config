{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  nix-update-script,
}: let
  pname = "es-de";
  version = "3.1.0";

  src = fetchurl {
    url = "https://gitlab.com/es-de/emulationstation-de/-/package_files/246875981/download";
    hash = "sha256-TLZs/JIwmXEc+g7d2D22R0SmKU4C4//Rnuhn93qI7H4=";
    name = "ES-DE_v${version}.AppImage";
  };

  contents = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # fix OpenGL renderer on nvidia + wayland
    extraBwrapArgs = [
      "--ro-bind-try /etc/egl/egl_external_platform.d /etc/egl/egl_external_platform.d"
    ];

    extraInstallCommands = ''
      . ${makeWrapper}/nix-support/setup-hook

      install -m 444 -D ${contents}/org.es_de.frontend.desktop $out/share/applications/es-de.desktop
      substituteInPlace $out/share/applications/es-de.desktop \
        --replace-fail 'Icon=org.es_de.frontend' 'Icon=es-de'

      install -Dm444 ${contents}/usr/share/icons/hicolor/scalable/apps/org.es_de.frontend.svg \
        $out/share/icons/hicolor/scalable/apps/es-de.svg
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "EmulationStation Desktop Edition - a frontend for browsing and launching games";
      homepage = "https://es-de.org";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "es-de";
      platforms = ["x86_64-linux"];
    };
  }

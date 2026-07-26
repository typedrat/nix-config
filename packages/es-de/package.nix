{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  writeShellApplication,
  curl,
  jq,
  gnused,
  gnugrep,
  coreutils,
}: let
  pname = "es-de";
  version = "3.4.1";

  src = fetchurl {
    url = "https://gitlab.com/es-de/emulationstation-de/-/package_files/288156961/download";
    hash = "sha256-PGGkTXONVRY9qljt5wcgtCWg32JGDATcI908pYZyNYE=";
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

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "es-de-update";
      runtimeInputs = [
        curl
        jq
        gnused
        gnugrep
        coreutils
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "EmulationStation Desktop Edition - a frontend for browsing and launching games";
      homepage = "https://es-de.org";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "es-de";
      platforms = ["x86_64-linux"];
    };
  }

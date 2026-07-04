{
  lib,
  appimageTools,
  fetchurl,
  writeShellApplication,
  curl,
  jq,
  nix,
  gnused,
  gnugrep,
  coreutils,
}: let
  pname = "krita";
  version = "5.3.2.1";

  src = fetchurl {
    url = "https://download.kde.org/stable/krita/${version}/krita-${version}-x86_64.AppImage";
    hash = "sha256-2UCS2qoa1CPYKnKX4LMcriz9zQ0GWVt/UPhGt2w7Puc=";
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
      # Desktop entries (main app plus per-format associations) and their MIME
      # definitions, copied verbatim — Exec/Icon already reference bare `krita`.
      install -Dm444 -t $out/share/applications ${contents}/usr/share/applications/*.desktop
      install -Dm444 -t $out/share/mime/packages ${contents}/usr/share/mime/packages/*.xml
      cp -r ${contents}/usr/share/icons $out/share/icons
    '';

    passthru.updateScript = lib.getExe (writeShellApplication {
      name = "krita-appimage-update";
      runtimeInputs = [
        curl
        jq
        nix
        gnused
        gnugrep
        coreutils
      ];
      text = builtins.readFile ./update.sh;
    });

    meta = {
      description = "Free and open source painting application, packaged from the official Qt5 AppImage";
      homepage = "https://krita.org";
      license = lib.licenses.gpl3Plus;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "krita";
      platforms = ["x86_64-linux"];
    };
  }

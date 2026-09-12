{
  lib,
  appimageTools,
  fetchurl,
  nix-update-script,
}: let
  pname = "sheepshaver-bin";
  version = "2026-09-11";

  src = fetchurl {
    url = "https://github.com/Korkman/macemu-appimage-builder/releases/download/${version}/SheepShaver-x86_64.AppImage";
    hash = "sha256-O9ZEMkBfWszLS0711yiSN7XIvya7/VlFV2tnJU4TDtk=";
  };

  contents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = pkgs: [pkgs.libthai];

    # AppRun cds to the AppImage's own directory so data files sitting beside it
    # are found, but the FHS wrapper never sets APPIMAGE, so that cd aborts on an
    # unbound variable. Anchor it to the invocation directory, which is where a
    # user's prefs file and disk images live anyway.
    profile = ''
      export APPIMAGE="$PWD/SheepShaver.AppImage"
    '';

    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/sheepshaver

      install -Dm444 -t $out/share/applications ${contents}/usr/share/applications/SheepShaver.desktop
      install -Dm444 -t $out/share/icons/hicolor/64x64/apps ${contents}/usr/share/icons/hicolor/64x64/apps/SheepShaver.png

      # The bundled entry (and its launch-option actions) exec the AppImage's
      # own binary name; point them all at the wrapper instead.
      substituteInPlace $out/share/applications/SheepShaver.desktop \
        --replace-fail "Exec=SheepShaver" "Exec=sheepshaver"
    '';

    passthru.updateScript = nix-update-script {
      # Releases are dated tags, plus a rolling "continuous" tag that is not a
      # version and must not be picked up.
      extraArgs = ["--flake" "--version-regex" "([0-9]{4}-[0-9]{2}-[0-9]{2})"];
    };

    meta = {
      description = "Open source PowerPC Mac OS run-time environment, packaged from Korkman's AppImage builds";
      homepage = "https://github.com/Korkman/macemu-appimage-builder";
      license = lib.licenses.gpl2Plus;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "sheepshaver";
      platforms = ["x86_64-linux"];
    };
  }

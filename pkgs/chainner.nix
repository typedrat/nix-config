{
  lib,
  fetchurl,
  stdenv,
  copyDesktopItems,
  electron,
  glib,
  libGL,
  makeDesktopItem,
  makeWrapper,
  unzip,
}:
stdenv.mkDerivation {
  pname = "chainner-bin";
  version = "0.25.1";
  src = fetchurl {
    url = "https://github.com/chaiNNer-org/chaiNNer/releases/download/v0.25.1/chaiNNer-linux-x64-0.25.1-portable.zip";
    sha256 = "sha256-BFl4S/C8veI/DV+ntesoUvAc3s1q8+LwFIEE3VuDyyU=";
  };

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    unzip
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p $out/{bin,libexec,share/icons/hicolor/256x256/apps}
    cp -r * $out/libexec

    makeWrapper ${lib.getExe electron} $out/bin/chainner \
      --add-flags $out/libexec/resources/app \
      --set LD_LIBRARY_PATH ${
      lib.makeLibraryPath [
        libGL
        glib
      ]
    }

    rm $out/libexec/portable

    ln -s $out/libexec/resources/app/.vite/renderer/main_window/256x256.png $out/share/icons/hicolor/256x256/apps/chainner.png

    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "chainner";
      desktopName = "chaiNNer";
      comment = "A flowchart-based image processing GUI";
      genericName = "Image Processing GUI";
      exec = "chainner %U";
      icon = "chainner";
      categories = ["Graphics"];
      mimeTypes = ["application/json"];
    })
  ];

  meta = with lib; {
    description = "A node-based image processing GUI aimed at making chaining image processing tasks easy and customizable.";
    homepage = "https://chainner.app/";
    license = licenses.gpl3Plus;
    mainProgram = "chainner";
    platforms = ["x86_64-linux"];
    sourceProvenance = [sourceTypes.binaryBytecode];
  };
}

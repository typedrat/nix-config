{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  xar,
  _7zz,
  neoaa,
}:
stdenvNoCC.mkDerivation {
  pname = "extract-apple-emoji";
  version = "0.1.0";

  src = ./extract-apple-emoji.py;
  dontUnpack = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/extract-apple-emoji
    wrapProgram $out/bin/extract-apple-emoji \
      --prefix PATH : ${lib.makeBinPath [xar _7zz neoaa]} \
      --set PYTHONPATH ${python3}/${python3.sitePackages}

    runHook postInstall
  '';

  meta = {
    description = "Extract Apple Color Emoji.ttc from a macOS InstallAssistant.pkg";
    license = lib.licenses.mit;
    mainProgram = "extract-apple-emoji";
    platforms = lib.platforms.linux;
  };
}

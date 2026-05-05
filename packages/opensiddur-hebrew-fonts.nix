{
  lib,
  stdenv,
  fetchFromGitHub,
  unzip,
  nix-update-script,
}:
stdenv.mkDerivation rec {
  pname = "opensiddur-hebrew-fonts";
  version = "0-unstable-2026-05-04";

  src = fetchFromGitHub {
    owner = "aharonium";
    repo = "fonts";
    rev = "2b5e366ffaa89d42159092fcccd6d027b50a9ef9";
    sha256 = "sha256-om+iq8TgpAj/pIOowccOY9ajRCUKnLlPlwTx8SHW2To=";
  };

  nativeBuildInputs = [unzip];

  dontBuild = true;

  sourceRoot = ".";

  postPatch = ''
    find . -type f -not -perm -644 -exec chmod 644 {} \;
  '';

  installPhase = ''
    runHook preInstall

    find $src/Fonts -name "*.ttf" -print -exec install -Dm644 {} -t $out/share/fonts/TTF/ \;
    find $src/Fonts -name "*.otf" -print -exec install -Dm644 {} -t $out/share/fonts/OTF/ \;

    # Remove Liberation fonts to prevent conflicts
    rm -f $out/share/fonts/TTF/Liberation*.ttf
    rm -f $out/share/fonts/OTF/Liberation*.otf

    # Install license
    install -Dm644 $src/LICENSES.txt $out/share/licenses/${pname}/LICENSE

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--version=branch"];
  };

  meta = with lib; {
    description = "The Open Siddur Project's Unicode Hebrew font pack. A large collection of open source Hebrew fonts, as well as a few for Latin, Greek, Cyrillic, Arabic, and Amharic";
    homepage = "https://github.com/aharonium/fonts";
    license = with licenses; [
      gpl3
      gpl2
      ofl
      asl20
      ufl
      lppl1
    ];
    platforms = platforms.all;
  };
}

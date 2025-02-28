{
  lib,
  stdenv,
  fetchFromGitHub,
  unzip,
}:
stdenv.mkDerivation rec {
  pname = "opensiddur-hebrew-fonts";
  version = "20240803";

  src = fetchFromGitHub {
    owner = "aharonium";
    repo = "fonts";
    rev = "bbde28cbfdb434807d480e3eac5b1ba796c79f47";
    sha256 = "sha256-8Lfq1U4tuceserKAMQaZq46GeFDbKbnwqQveiGePkUI=";
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

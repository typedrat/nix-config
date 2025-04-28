{
  lib,
  fetchFromGitHub,
  stdenv,
  python3,
  themeParkScheme ? "http",
  themeParkDomain ? "localhost",
}:
stdenv.mkDerivation rec {
  pname = "theme-park";
  version = "1.20.1";

  src = fetchFromGitHub {
    owner = "themepark-dev";
    repo = "theme.park";
    tag = version;
    sha256 = "sha256-6LRHW0ESfNRvWCrp84gepaBGBKcyJw+NFdR+x5pMQ+I=";
  };

  patches = [./remove-chdir.patch];

  nativeBuildInputs = [python3];

  buildPhase = ''
    runHook preBuild

    export TP_SCHEME=${themeParkScheme}
    export TP_DOMAIN=${themeParkDomain}
    cat themes.py
    python3 themes.py

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/theme-park
    cp -r css/ $out/share/theme-park/css/
    cp themes.json $out/share/theme-park/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted themes for various self-hosted applications";
    homepage = "https://github.com/themepark-dev/theme.park";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

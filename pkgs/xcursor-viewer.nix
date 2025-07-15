{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libsForQt5,
}:
stdenv.mkDerivation rec {
  pname = "xcursor-viewer";
  version = "unstable-2023-01-13";

  src = fetchFromGitHub {
    owner = "drizt";
    repo = pname;
    rev = "6b8a95a6071d860ee6f9b8e82695cd09d9e6ff31";
    hash = "sha256-65oL1zVNFhKM2ePNvWdSyUIEkHGktNFP5k0/oI+S2j0=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    libsForQt5.qt5.wrapQtAppsHook
  ];

  buildInputs = [
    libsForQt5.qt5.qtbase
  ];

  meta = with lib; {
    description = "View XCursor files in list";
    homepage = "https://github.com/drizt/xcursor-viewer";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}

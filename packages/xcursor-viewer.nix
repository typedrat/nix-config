{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libsForQt5,
  nix-update-script,
}:
stdenv.mkDerivation rec {
  pname = "xcursor-viewer";
  version = "0-unstable-2026-01-27";

  src = fetchFromGitHub {
    owner = "drizt";
    repo = pname;
    rev = "f53e1d261458e84b0f76fb587af560841c413087";
    hash = "sha256-fWkjcXmtU51AQOTK1nLx7Kw9kQtQhUz9EVtAAVX0WEg=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    libsForQt5.qt5.wrapQtAppsHook
  ];

  buildInputs = [
    libsForQt5.qt5.qtbase
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--version=branch"];
  };

  meta = with lib; {
    description = "View XCursor files in list";
    homepage = "https://github.com/drizt/xcursor-viewer";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}

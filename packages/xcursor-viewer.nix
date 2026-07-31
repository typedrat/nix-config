{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt5,
  nix-update-script,
}:
stdenv.mkDerivation rec {
  pname = "xcursor-viewer";
  version = "0-unstable-2026-07-26";

  src = fetchFromGitHub {
    owner = "drizt";
    repo = pname;
    rev = "7ce7c1bbcfbc5543f4965e59e6ce496098319aeb";
    hash = "sha256-e0FOkbPqkgZMxNHAosiORQv90sktQWIhMl96gZZrLoA=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    qt5.qtbase
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

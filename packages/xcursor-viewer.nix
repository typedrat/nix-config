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
  version = "0-unstable-2026-09-19";

  src = fetchFromGitHub {
    owner = "drizt";
    repo = pname;
    rev = "6e6c80ddd44498b052976871201ec75e09cc4e64";
    hash = "sha256-vjKQRdZ6viqH9jP0roOSBtnDx59ZHQSoERipTNkbAKI=";
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

{
  stdenv,
  fetchFromGitHub,
  libffi,
  libxkbcommon,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
}:
stdenv.mkDerivation {
  pname = "wayland-getevent";
  version = "unstable-20241211";

  src = fetchFromGitHub {
    owner = "Xtr126";
    repo = "wayland-getevent";
    rev = "1fbf7af0c1ca15c43ad4f65eb63e683d30715a94";
    hash = "sha256-jCYx/buiJdCOlwOt0M3YgKAWD4ho1/6KfIbL6ZfWrEA=";
  };

  nativeBuildInputs = [
    pkg-config
    wayland-protocols
    wayland-scanner
  ];

  buildInputs = [
    libffi
    libxkbcommon
    wayland
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 client $out/bin/wayland-getevent
    runHook postInstall
  '';
}

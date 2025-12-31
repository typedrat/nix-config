{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cargo-tauri,
  glib-networking,
  nodejs,
  openssl,
  pkg-config,
  webkitgtk_4_1,
  wrapGAppsHook4,
  fetchPnpmDeps,
  pnpmConfigHook,
  bun,
  python3,
  uv,
}:
rustPlatform.buildRustPackage rec {
  pname = "tome";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "runebookai";
    repo = "tome";
    rev = "${version}";
    hash = "sha256-W7e0pQ5jSKEcNivABSIgTzcU3pGwi4NjSNaY5xQ+4/8=";
  };

  patches = [
    ./disable-updater.patch
  ];

  cargoHash = "sha256-tUmzNKmDHwpqays0WCy55R5y42K9JamRtdaAwnyeZck=";

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    hash = "sha256-krf4KZvcwBi/fGzsmGoIo/uHD0/3bycbCdbZDwRhLd4=";
  };

  nativeBuildInputs =
    [
      cargo-tauri.hook

      nodejs
      pnpmConfigHook

      pkg-config
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      wrapGAppsHook4
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    glib-networking
    openssl
    webkitgtk_4_1
    nodejs
    bun
    python3
    uv
  ];

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  meta = with lib; {
    description = "A magical desktop app that puts the power of LLMs and MCP in the hands of everyone";
    homepage = "https://gettome.app";
    license = licenses.asl20;
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "tome";
  };
}

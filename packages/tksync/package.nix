{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tksync";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "rhedgeco";
    repo = "tksync";
    tag = finalAttrs.version;
    hash = "sha256-MXIWRUe96qfuXRrLDXw+zrFsLHjyS/pIqG2H4IYFngs=";
  };

  cargoHash = "sha256-AVCQkH2YJkgI4Vy228ktKZjMC+6UsJVPS1JkrqF5fDE=";

  patches = [
    # Adobe began serving variable fonts after this tool was last released, and
    # their `@font-face` blocks carry a weight range (`font-weight:100 900`)
    # that the CSS parser hit an `unreachable!()` on, aborting the whole sync.
    ./variable-fonts.patch
  ];

  # Cargo.toml was never bumped at the 0.1.2 tag, so `tksync --version` would
  # otherwise report 0.1.1.
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail 'version = "0.1.1"' 'version = "${finalAttrs.version}"'
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Unofficial tool for downloading fonts from Adobe Fonts (Typekit) web projects";
    homepage = "https://github.com/rhedgeco/tksync";
    license = lib.licenses.mit;
    mainProgram = "tksync";
    platforms = lib.platforms.unix;
  };
})

{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  dbus,
  openssl,
  nix-update-script,
}:
rustPlatform.buildRustPackage (_finalAttrs: {
  pname = "catbox-cli";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "JustSimplyKyle";
    repo = "catbox-cli";
    rev = "9b19dc2ee2d058cd758ff1afa85eb01dc9320a2e";
    hash = "sha256-ZZt/j3ehX7nKpTX3BJMb4lDQOgFCIMXNJM9HrA4Ddlc=";
  };

  cargoHash = "sha256-X0CQnBki90gjPNMdnbwNt1ImWXdMTQHDpak4/wB9nwU=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
    openssl
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = ["--version=branch"];
  };

  meta = with lib; {
    description = "A simple catbox cli app that has progress when uploading!";
    homepage = "https://github.com/JustSimplyKyle/catbox-cli";
    license = licenses.mit;
    mainProgram = "cbx";
    maintainers = [];
  };
})

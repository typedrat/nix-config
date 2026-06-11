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
  version = "0.2.0-unstable-2026-05-11";

  src = fetchFromGitHub {
    owner = "JustSimplyKyle";
    repo = "catbox-cli";
    rev = "c0788d8946dc178f36132c822b8709c819b4cb7a";
    hash = "sha256-8ubSEO1LQsi/fjyV6qxJVy30uhPC+AwxJd4HKVly0/A=";
  };

  cargoHash = "sha256-Cr3/+54GdJFlPRP3PW42MMpXNIoeZnde3U6xfhpupOM=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
    openssl
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--version=branch"];
  };

  meta = with lib; {
    description = "A simple catbox cli app that has progress when uploading!";
    homepage = "https://github.com/JustSimplyKyle/catbox-cli";
    license = licenses.mit;
    mainProgram = "cbx";
    maintainers = [];
  };
})

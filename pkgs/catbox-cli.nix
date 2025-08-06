{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  dbus,
  openssl,
}:
rustPlatform.buildRustPackage (_finalAttrs: {
  pname = "catbox-cli";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "JustSimplyKyle";
    repo = "catbox-cli";
    rev = "4629bebea82544dd4e79863321c11cb53c77593a";
    hash = "sha256-BVcdMEGpZCWIwzYfxhV9PghiLPAc4vViM+UrMFkatHY=";
  };

  cargoHash = "sha256-zF+j7kDvOggBvN/Dl7gI1v8FKUsB3nKDHPQlf3KKC74=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
    openssl
  ];

  meta = with lib; {
    description = "A simple catbox cli app that has progress when uploading!";
    homepage = "https://github.com/JustSimplyKyle/catbox-cli";
    license = licenses.mit;
    maintainers = [];
  };
})

{
  lib,
  rustPlatform,
  fetchFromGitHub,
  bchunk,
  ctrtool,
  dolphin-emu,
  flips,
  mame,
  maxcso,
  nsz,
  p7zip,
  pkg-config,
  wiimms-iso-tools,
  xdelta,
  openssl,
  sqlite,
  stdenv,
  darwin,
}:
rustPlatform.buildRustPackage rec {
  pname = "oxyromon";
  version = "0.20.2";

  src = fetchFromGitHub {
    owner = "alucryd";
    repo = "oxyromon";
    rev = version;
    hash = "sha256-vfGth3CBUOmh9ViWdXKT3PPs4J0w//EJXEokRSLiQt8=";
  };

  cargoHash = "sha256-QkOTc2tsU2f6LXIiPG2SJOIlZaPx0RxeCMSPf28oeVw=";

  nativeBuildInputs = [
    bchunk
    ctrtool
    dolphin-emu
    flips
    mame.tools
    maxcso
    nsz
    p7zip
    pkg-config
    wiimms-iso-tools
    xdelta
  ];

  buildInputs =
    [
      openssl
      sqlite
    ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ];

  meta = {
    description = "Rusty ROM OrgaNizer";
    homepage = "https://github.com/alucryd/oxyromon?tab=readme-ov-file";
    changelog = "https://github.com/alucryd/oxyromon/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [typedrat];
    mainProgram = "oxyromon";
  };
}

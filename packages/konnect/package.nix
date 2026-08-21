{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  protobuf,
  makeWrapper,
  cacert,
  kicad,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "konnect";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "mixelpixx";
    repo = "Konnect";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6G4gR8YMiSbrW3c66NkdOkDNVBdbr8qZM5e9GbgQaUA=";
  };

  cargoHash = "sha256-3ox5nXA/jkOsv5Ii9TfGVkREiAmaaCgOxJAQbkPL0RA=";

  nativeBuildInputs = [
    # nng-sys compiles the bundled NNG C library.
    cmake
    # konnect-ipc generates the KiCAD IPC protobuf bindings at build time. Its
    # build.rs derives the well-known-type include dir as <protoc>/../../include,
    # which lands on protobuf's own $out/include.
    protobuf
    makeWrapper
  ];

  # There is no CMakeLists.txt at the root; only the nng-sys build script drives
  # cmake, and it does so itself.
  dontUseCmakeConfigure = true;

  nativeCheckInputs = [cacert];

  # Builds on a ZFS dataset created with utf8only=on — every one here — can't
  # create the deliberately non-UTF-8 filename this exercises, and the pool
  # property is fixed at creation time. The sibling cases that only encode or
  # compare such a name, rather than create it, still run.
  checkFlags = [
    "--skip=transaction::tests::transaction_recovers_a_non_unicode_target_path_on_linux"
  ];

  # HOME: every schematic write takes a lock file under the platform local-data
  # dir, which resolves to $HOME/.local/share — unwritable as the sandbox's
  # /homeless-shelter, so the file-based protocol test fails on it.
  #
  # SSL_CERT_FILE: reqwest::Client::new() panics outright when rustls finds no
  # trust store. The HTTP tests only talk plain http to a loopback socket, so
  # any bundle will do — they just need a client to exist.
  preCheck = ''
    export HOME=$(mktemp -d)
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  # Exports, ERC/DRC, and schematic rendering shell out to `kicad-cli`, looked up
  # bare on PATH. Suffixed so a KiCAD the user installed themselves still wins —
  # the CLI has to match the KiCAD generating the files it reads.
  postInstall = ''
    wrapProgram $out/bin/konnect \
      --suffix PATH : ${lib.makeBinPath [kicad]}
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "AI-assisted PCB design for KiCAD 10 over the Model Context Protocol";
    homepage = "https://github.com/mixelpixx/Konnect";
    license = lib.licenses.agpl3Only;
    mainProgram = "konnect";
    platforms = lib.platforms.linux;
  };
})

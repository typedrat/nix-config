{
  lib,
  rustPlatform,
  fetchgit,
  pkg-config,
  llvmPackages,
  nettle,
  pcsclite,
  zbar,
  installShellFiles,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "keyfork";
  version = "0.3.4";

  src = fetchgit {
    url = "https://git.distrust.co/public/keyfork";
    rev = "keyfork-v${version}";
    hash = "sha256-lJ2sOJUVnlZNWaU84zYyABnzOu9F0bZTW8/2PkNVlfQ=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [
    pkg-config
    installShellFiles
    llvmPackages.clang
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  buildInputs = [
    nettle # For sequoia-openpgp
    pcsclite # For smart card support
    zbar # For QR code decoding
  ];

  # Only build the main keyfork binary
  cargoBuildFlags = ["-p" "keyfork"];
  cargoTestFlags = ["-p" "keyfork"];

  postInstall = ''
    installShellCompletion --cmd keyfork \
      --bash <($out/bin/keyfork completion bash) \
      --zsh <($out/bin/keyfork completion zsh) \
      --fish <($out/bin/keyfork completion fish)
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Opinionated toolchain for managing cryptographic keys offline and on smartcards";
    homepage = "https://git.distrust.co/public/keyfork";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [typedrat];
    mainProgram = "keyfork";
  };
}

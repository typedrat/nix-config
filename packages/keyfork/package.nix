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
  version = "0.3.6";

  src = fetchgit {
    url = "https://git.distrust.co/public/keyfork";
    rev = "keyfork-v${version}";
    hash = "sha256-9WKHEseblmRjmCZr+wofGHF+aVZb8gUTwJphzH3JDn0=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
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

  passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version-regex" "keyfork-v(.*)"];};

  meta = {
    description = "Opinionated toolchain for managing cryptographic keys offline and on smartcards";
    homepage = "https://git.distrust.co/public/keyfork";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [typedrat];
    mainProgram = "keyfork";
  };
}

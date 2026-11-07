{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeBinaryWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "configarr";
  version = "1.39.1";

  src = fetchFromGitHub {
    owner = "raydak-labs";
    repo = "configarr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aGuGUQMv2waFQe0x+Z+wCoi6qGsaNL6ELT0DVHI28RQ=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeBinaryWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-ZV6qMCzK5GyysnZekyWj89RpsYETlMtyfiyqLbqmRh0=";
  };

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck

    pnpm test

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 -t $out/share bundle.cjs

    makeWrapper ${lib.getExe nodejs} $out/bin/configarr \
      --add-flags "$out/share/bundle.cjs"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Sync TRaSH Guides + custom configs with Sonarr/Radarr";
    homepage = "https://github.com/raydak-labs/configarr";
    changelog = "https://github.com/raydak-labs/configarr/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [lord-valen];
    mainProgram = "configarr";
    platforms = lib.platforms.all;
  };
})

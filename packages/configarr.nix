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
  version = "1.27.0";

  src = fetchFromGitHub {
    owner = "raydak-labs";
    repo = "configarr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kwBh6h+OCC7VxB06Mf/VQuduYKOAEpfrJYrKzmoAqPM=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeBinaryWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-niCF2rfMuj0V0uDrX8rWk43fdLAM0dyS77DVjJv4//Y=";
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

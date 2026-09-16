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
  version = "1.31.0";

  src = fetchFromGitHub {
    owner = "raydak-labs";
    repo = "configarr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-92qvslF6Rfr/ZPIgi+IYO5eZE4ZaK+P6tJ/K1264Lrg=";
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
    hash = "sha256-552lvoV/91XuqL2W3plI8jhWcIloIjOxzCpkRAW4yMU=";
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

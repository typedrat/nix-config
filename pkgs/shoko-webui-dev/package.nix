{
  stdenvNoCC,
  fetchFromGitHub,
  git,
  nodejs,
  pnpm,
  lib,
  nix-update-script,
  dotnet-sdk_8,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shoko-webui-dev";
  version = "2.3.0-dev.18";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "Shoko-WebUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-YUnilm3cIwRkhrHkCFuQXO/d4uhs/UVCMZTSAGh/HlM=";
    leaveDotGit = true;
  };

  nativeBuildInputs = [
    git
    nodejs
    pnpm.configHook
  ];

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-kek68gwwVdH+GdG8aUSW1oUSmmBChpJ8v5Kcr8TXV9o=";
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';

  passthru.updateSript = nix-update-script {};

  meta = {
    homepage = "https://github.com/ShokoAnime/Shoko-WebUI";
    changelog = "https://github.com/ShokoAnime/Shoko-WebUI/releases/tag/v${finalAttrs.version}";
    description = "Web-based frontend for the Shoko anime management system";
    maintainers = [lib.maintainers.diniamo];
    license = lib.licenses.mit;
    inherit (dotnet-sdk_8.meta) platforms;
  };
})

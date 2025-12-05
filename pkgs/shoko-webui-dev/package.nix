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
  version = "2.4.0-dev.2";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "Shoko-WebUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-jaRuH087pxHFAGYjzatPylo7bXFz8T0/Bn0MwXBBKro=";
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
    hash = "sha256-lSLD2CLUojDs6TnDr4915kpyQKKYHJxjk/42av1hqVI=";
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

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
  version = "2.2.1-dev.27";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "Shoko-WebUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gcH2TotJoH65doaeIk/bzntLKRgt5XSEPgsOQAUu68M=";
    leaveDotGit = true;
  };

  nativeBuildInputs = [
    git
    nodejs
    pnpm.configHook
  ];

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-9/6y8LhH0I6RAry+3shvsymLZb7ndugq3EGG3S/yrIA=";
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

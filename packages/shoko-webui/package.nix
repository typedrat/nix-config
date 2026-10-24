{
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  shoko,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shoko-webui";
  # The dev line, which is what the server's dev channel pairs with.
  version = "2.6.0-dev.153";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "Shoko-WebUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Dqoega+AWIsRZg6qREJMRXCq7DVGwYmMQ2eI1yhqlls=";
  };

  # The build stamps the git commit into the bundle for the updater, which a
  # declaratively managed web UI never uses, and the source has no .git.
  postPatch = ''
    substituteInPlace vite.config.mjs \
      --replace-fail \
        $'childProcess.execSync("git log --pretty=format:\'%h\' -n 1").toString().replace(/["\']/g, \'\')' \
        "'''"
  '';

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm_10
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-br70KFFsx3vO9MeAhE8uuORPwrEA9mxJwV9jjsvC1Dw=";
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

  passthru.updateScript = ./update.sh;

  meta = {
    homepage = "https://github.com/ShokoAnime/Shoko-WebUI";
    changelog = "https://github.com/ShokoAnime/Shoko-WebUI/releases/tag/v${finalAttrs.version}";
    description = "Web-based frontend for the Shoko anime management system";
    inherit (shoko.meta) license platforms;
  };
})

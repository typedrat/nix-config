{
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  fetchPnpmDeps,
  jq,
  shoko,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "shoko-webui";
  # The dev line, which is what the server's dev channel pairs with.
  version = "2.6.0-dev.158";

  src = fetchFromGitHub {
    owner = "ShokoAnime";
    repo = "Shoko-WebUI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4D+S1eflDzHWoJMfBCLFlV2G8mWcoigjSsR4N6A5lNo=";
  };

  postPatch = ''
    # The update prompt compares the newest release with package.json's
    # version, which upstream's release builds stamp with the full tag. Left as
    # the bare "2.6.0-dev" it is older than any dev release, so it always prompts.
    jq --arg version ${finalAttrs.version} '.version = $version' package.json > package.json.new
    mv package.json.new package.json

    # The build stamps the git commit into the bundle for the updater, which a
    # declaratively managed web UI never uses, and the source has no .git.
    substituteInPlace vite.config.mjs \
      --replace-fail \
        $'childProcess.execSync("git log --pretty=format:\'%h\' -n 1").toString().replace(/["\']/g, \'\')' \
        "'''"
  '';

  nativeBuildInputs = [
    jq
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

{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  gh,
  makeBinaryWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ghui";
  version = "0.7.1";

  src = fetchFromGitHub {
    owner = "kitlangton";
    repo = "ghui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kw8Rk82s9i4+sAzTrwbnbRFd6TKHZAtW+pqI983exto=";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
  ];

  # Fixed-output derivation containing the bun-resolved node_modules tree.
  # Hash will need updating whenever bun.lock changes.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [bun];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)
      bun install --frozen-lockfile --no-progress --ignore-scripts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib
      rm -rf ./node_modules/.cache
      cp -R ./node_modules $out/lib/node_modules

      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-uqZzZhBNWQkcvEzuKjfD2r2HqWqMUqdXujqYlGMAbbQ=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/ghui
    cp -R src bin package.json $out/share/ghui/
    ln -s ${finalAttrs.node_modules}/lib/node_modules $out/share/ghui/node_modules

    makeBinaryWrapper ${lib.getExe bun} $out/bin/ghui \
      --add-flags "run --prefer-offline --no-install $out/share/ghui/src/index.tsx" \
      --prefix PATH : ${lib.makeBinPath [gh]}

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Terminal UI for browsing and acting on your open GitHub pull requests across repositories";
    homepage = "https://github.com/kitlangton/ghui";
    changelog = "https://github.com/kitlangton/ghui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "ghui";
    platforms = lib.platforms.unix;
  };
})

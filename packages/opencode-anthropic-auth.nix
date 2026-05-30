{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchpatch,
  bun,
  nodejs,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode-anthropic-auth";
  version = "1.8.1";

  src = fetchFromGitHub {
    owner = "ex-machina-co";
    repo = "opencode-anthropic-auth";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ScWQEEiwHQPt6MVzm3YKlC04/8eZ6HO5ZwOtqx84p0M=";
  };

  patches = [
    (fetchpatch {
      name = "opencode-anthropic-auth-pr-150.patch";
      url = "https://github.com/ex-machina-co/opencode-anthropic-auth/pull/150.diff";
      hash = "sha256-RQAqrLySOvDhh8w4OSkVHp4UkPBLHNoRQToqUZXwbKA=";
    })
  ];

  nativeBuildInputs = [
    bun
    nodejs
  ];

  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src patches;

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

    outputHash = "sha256-YvFN8HtiUhPJJ9yG0cikSyJSuBP+cBHAneDN1MmF2yo=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    ln -s ${finalAttrs.node_modules}/lib/node_modules node_modules
    export HOME=$(mktemp -d)
    ${lib.getExe nodejs} node_modules/typescript/bin/tsc -p tsconfig.build.json
    bun build dist/index.js --target=bun --outfile=opencode-anthropic-auth.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 opencode-anthropic-auth.js $out/share/opencode/plugins/opencode-anthropic-auth.js

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "OpenCode Anthropic OAuth plugin with PR 150 hybrid prompt caching patch";
    homepage = "https://github.com/ex-machina-co/opencode-anthropic-auth";
    changelog = "https://github.com/ex-machina-co/opencode-anthropic-auth/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})

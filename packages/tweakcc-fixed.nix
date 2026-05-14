{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  autoPatchelfHook,
  makeBinaryWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tweakcc-fixed";
  # Latest tag (v4.0.11) predates the Bun >=1.3 `.bun` ELF section support
  # that Claude Code 2.1.x ships with, so native-binary extraction fails on
  # the Nix `claude-code` package. Tracking `main` until skrabe cuts a new
  # tag with the upstream v4.0.13 merge.
  version = "4.0.11-unstable-2026-05-14";

  src = fetchFromGitHub {
    owner = "skrabe";
    repo = "tweakcc-fixed";
    rev = "3dd53da605dcb7afff324c7de4bdad6848ed4f9a";
    hash = "sha256-obX90caFwut2swc9fq5xmq/W6/FdJF9HLqOCqhx2hXU=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 2;
    hash = "sha256-IECGektWlYDHY4Iljx5U5TJFLBiiT+kke6AgPIMnDgE=";
  };

  nativeBuildInputs =
    [
      nodejs
      pnpm_10
      pnpmConfigHook
      makeBinaryWrapper
    ]
    ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  # node-lief ships a prebuilt .node addon that dynamically links against
  # libstdc++ and libgcc_s. autoPatchelfHook needs the runtime libs in
  # buildInputs to rewrite the RPATH; without it the build sandbox can run
  # tweakcc-fixed once but consumers that load LIEF inside their own
  # sandbox (e.g. claude-code-patched) segfault on dlopen.
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

  # node-lief also ships musl prebuilds we never load on glibc hosts.
  # node-gyp-build picks `.node` over `.musl.node` at runtime, so it's
  # safe to leave the musl-only libc dep unsatisfied. Pattern covers
  # x86_64, aarch64, and any future musl arches.
  autoPatchelfIgnoreMissingDeps = ["libc.musl-*.so.*"];

  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  # Drop dev dependencies and non-deterministic / unnecessary files.
  preInstall = ''
    CI=true pnpm --ignore-scripts --prod prune
    find . -type f \( -name "*.ts" -not -name "*.d.ts" -o -name "*.map" \) -delete
    # https://github.com/pnpm/pnpm/issues/3645
    find node_modules -xtype l -delete
    rm -f node_modules/.modules.yaml
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/tweakcc-fixed $out/bin
    cp -R dist node_modules package.json $out/lib/tweakcc-fixed/

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/tweakcc-fixed \
      --add-flags "$out/lib/tweakcc-fixed/dist/index.mjs"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--version=branch"];
  };

  meta = {
    description = "Fork of tweakcc with cherry-picked upstream fixes and additional patches for newer Claude Code versions";
    longDescription = ''
      tweakcc-fixed (skrabe's fork) carries fixes for upstream tweakcc that
      aren't merged yet, plus features specific to that maintainer's workflow,
      including a system-reminder override mechanism, MCP per-server instruction
      routing, a Skills view, and CC 2.1.113+ minifier-shape patches.
    '';
    homepage = "https://github.com/skrabe/tweakcc-fixed";
    changelog = "https://github.com/skrabe/tweakcc-fixed/blob/${finalAttrs.src.rev}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "tweakcc-fixed";
    platforms = lib.platforms.unix;
  };
})

{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  autoPatchelfHook,
  makeBinaryWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tweakcc-fixed";
  version = "2.7.1";

  # Tracks skrabe/tweakcc-fixed upstream. We previously pinned a typedrat fork
  # carrying a \uXXXX-escape fix for injected non-ASCII glyphs (raw multibyte
  # UTF-8 — spinner phases, verb accents, the "patches applied" notice bar/check
  # — spliced into CC's cli.js renders as mojibake because Bun stores modules as
  # Latin-1). That fix landed upstream in v2.0.13 (escapes to match esbuild's
  # charset=ascii output), so the fork has been retired in favour of upstream.
  src = fetchFromGitHub {
    owner = "skrabe";
    repo = "tweakcc-fixed";
    rev = "v${finalAttrs.version}";
    hash = "sha256-uCD5fGjfwEv3J/wXr2HHhsXyRfFnXkw69T+4gmUc96w=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-+zW1FPbgPx7mzsYf+5VmOwI8i8nLGVz6mJ2tpsD9DHQ=";
  };

  nativeBuildInputs =
    [
      nodejs
      pnpm
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

  # Upstream tweakcc-fixed added a post-repack sanity check that spawns the
  # patched binary with `--version` to confirm it boots. That
  # check is a false positive under Nix: claude-code-patched runs tweakcc in
  # preFixup — *before* autoPatchelfHook rewrites the ELF interpreter to the
  # Nix store path (deliberate ordering, since LIEF can't parse a post-
  # autoPatchelf ELF). The binary therefore can't start inside the build
  # sandbox even though it runs fine once the build completes. Drop the check;
  # claude-code-patched verifies `claude --version` itself after the full build.
  postPatch = ''
    substituteInPlace src/patches/index.ts \
      --replace-fail \
        "assertNativeBinaryStarts(tempBinaryPath);" \
        "/* assertNativeBinaryStarts disabled: false positive pre-autoPatchelf under Nix */"
  '';

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
    # `data/prompts/` is resolved at runtime; without it tweakcc-fixed
    # falls back to fetching from GitHub, which fails in offline contexts.
    cp -R dist node_modules package.json data $out/lib/tweakcc-fixed/

    makeBinaryWrapper ${lib.getExe nodejs} $out/bin/tweakcc-fixed \
      --add-flags "$out/lib/tweakcc-fixed/dist/index.mjs"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
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

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
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tweakcc-fixed";
  version = "2.7.37";

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
    hash = "sha256-AsDw1EVn8zDypBby/MA2fC3DWNXutRrIrRKrCHSabtA=";
  };

  # Repacking a Bun single-file executable appends the rebuilt .bun after the
  # original instead of over it, so every patched claude-code carries two copies
  # of a ~238MB section (324MB -> 561MB). Upstream's compact placement only
  # removes the coarse alignment gap between them, not the duplicate.
  #
  # Rebase of skrabe/tweakcc-fixed#27, which still targets the pre-2.7.37 shape
  # of repackELFSection and no longer applies; the new placement inputs are
  # optional so the upstream placement tests keep type-checking.
  patches = [
    ./no-binary-bloat-when-patching-linux-installs.patch
  ];

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

  passthru = {
    # System-prompt / system-reminder overrides consumed by
    # claude-code-patched. Pinned here rather than there because the
    # overrides are written against the tweakcc patch shapes, so both
    # must be bumped together; update.sh keeps them in lockstep.
    promptOverrides = fetchFromGitHub {
      owner = "skrabe";
      repo = "lobotomized-claude-code";
      rev = "e0e969b7125d6b1381ec650b24bb2efa0949347d";
      hash = "sha256-LKUyrAnQ8BNm2Bg4uAVi18JAIp00bNfPRoGXf7GmUYg=";
    };

    updateScript = ./update.sh;
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

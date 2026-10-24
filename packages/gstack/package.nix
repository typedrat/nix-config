{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgsStatic,
  autoPatchelfHook,
  bun,
  coreutils,
  nodejs,
  git,
  jq,
  perl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "gstack";
  version = "1.91.186.0";

  # Upstream publishes no tags; VERSION at the pinned commit is the version.
  src = fetchFromGitHub {
    owner = "garrytan";
    repo = "gstack";
    rev = "00100f1598dcfc192f0f0f2d3345b6825737932a";
    hash = "sha256-0BElTDb2GtFo6ZvHNPZcM38/R80KjVk65sXr1BlspM0=";
  };

  # bun only installs the optional native packages (sharp, onnxruntime, ngrok)
  # for the platform it runs on, so this hash is per-system.
  node_modules = stdenv.mkDerivation {
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

      rm -rf node_modules/.cache
      cp -R node_modules $out

      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-mwi1wEPxRC3HPJPlqHG0gLGflEqt5fqtdO7+hBbXdF0=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    bun
    nodejs
    git
    jq
    perl
  ];

  buildInputs = [stdenv.cc.cc.lib];

  # The /cso launcher is linked with -static, and a static glibc binary
  # dlopens libgcc_s at runtime; musl doesn't.
  env.CSO_CC = "${pkgsStatic.stdenv.cc}/bin/${pkgsStatic.stdenv.cc.targetPrefix}cc";

  # onnxruntime ships GPU execution providers that are only loaded on demand.
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libcudart.so.*"
    "libcublas.so.*"
    "libcublasLt.so.*"
    "libcudnn.so.*"
    "libcufft.so.*"
    "libcurand.so.*"
    "libnvinfer.so.*"
    "libnvonnxparser.so.*"
  ];

  # The compiled binaries are bun executables with the bundle appended, and
  # the /cso launcher refuses a core whose sha256 changed after the build, so
  # only the prebuilt native modules get patched.
  dontStrip = true;
  dontPatchELF = true;
  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf $out/share/gstack/node_modules
  '';

  # Everything is built in its final location: setup's runtime roots are
  # symlinks into the checkout, so the checkout has to already be $out.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    root=$out/share/gstack
    mkdir -p $out/share
    cp -R ${finalAttrs.src} $root
    chmod -R u+w $root
    cp -R ${finalAttrs.node_modules} $root/node_modules
    chmod -R u+w $root/node_modules
    # bun installs the musl builds of native packages next to the glibc ones;
    # only the glibc builds are ever loaded here.
    find $root/node_modules -mindepth 2 -maxdepth 2 -type d \
      \( -name '*-musl' -o -name '*linuxmusl*' \) -exec rm -rf {} +
    patchShebangs $root

    # The browser probe launches Playwright's own Chromium and installs one
    # when that fails; honor a configured Chromium instead.
    substituteInPlace $root/bin/gstack-browser-ensure \
      --replace-fail 'chromium.launch({ timeout: 30000, args })' \
                     'chromium.launch({ timeout: 30000, args, executablePath: process.env.GSTACK_CHROMIUM_PATH || undefined })'

    substituteInPlace $root/scripts/build-cso.sh \
      --replace-fail '[ -x /usr/bin/sha256sum ];then digest="$(/usr/bin/sha256sum' \
                     '[ -x ${coreutils}/bin/sha256sum ];then digest="$(${coreutils}/bin/sha256sum'

    export HOME=$TMPDIR/home
    mkdir -p $HOME/.claude $HOME/.codex $HOME/.config/opencode
    export GSTACK_HOME=$TMPDIR/state

    printf '%s\n' claude codex opencode > $root/.gstack-installed-hosts

    (
      cd $root
      for host in claude codex opencode; do
        ./setup --host "$host" --no-browser --no-prefix
      done
    )

    # Each host's install tree, ready to be linked into a real home directory.
    mkdir -p $out/share/gstack-hosts/{claude,codex,opencode}
    cp -a $HOME/.claude/skills $out/share/gstack-hosts/claude/skills
    cp -a $HOME/.codex/skills $out/share/gstack-hosts/codex/skills
    cp -a $HOME/.config/opencode/skills $out/share/gstack-hosts/opencode/skills
    if [ -d $HOME/.config/opencode/commands ]; then
      cp -a $HOME/.config/opencode/commands $out/share/gstack-hosts/opencode/commands
    fi

    # Upgrades come from bumping this package, and the self-upgrade skill
    # would try to git-pull the store path. gstack refuses to disable it.
    rm -rf $out/share/gstack-hosts/{claude,codex,opencode}/skills/gstack-upgrade \
      $out/share/gstack-hosts/opencode/commands/gstack-upgrade.md

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Claude Code skills and headless browser tooling from Garry Tan";
    homepage = "https://github.com/garrytan/gstack";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
})

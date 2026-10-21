{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  nodejs,
  zip,
  icoutils,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "patreon-dl-gui";
  version = "2.10.0";

  src = fetchFromGitHub {
    owner = "patrickkfkan";
    repo = "patreon-dl-gui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-nQZCyreT1Ci+E3wPNYGjO9SIuzfJkW5AKZ781BNYLgQ=";
  };

  # Bumps better-sqlite3 to 13, whose N-API prebuilds load under any Electron
  # (12.x no longer compiles against current V8), drops the postPackage hook
  # (it runs `npm install` and electron-rebuild against the network) and the
  # `pkg`-built helper binary, and pins the helper path, since
  # process.resourcesPath points into Electron's own dist when the app is
  # launched by a wrapper.
  patches = [
    ./offline-packaging.patch
    # Patreon's page data no longer names the target, so "No target identified"
    # appeared on every page; this falls back to the browser URL.
    # patrickkfkan/patreon-dl-gui#88 at b02bb88
    ./target-from-url.patch
  ];

  postPatch = ''
    substituteInPlace src/main/Constants.ts \
      --subst-var-by patreonDlEmbed "$out/libexec/patreon-dl-embed"
  '';

  npmDepsHash = "sha256-OSHA0lRQLBgg0spHF0R7+5I66KV+8hyF9mZ6Jdqs2jk=";
  # The only git dependency is a maker-rpm override that is never run here.
  forceGitDeps = true;
  npmFlags = ["--ignore-scripts"];
  makeCacheWritable = true;

  nativeBuildInputs = [
    zip
    icoutils
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [stdenv.cc.cc.lib];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # electron-forge squeezes its output into one narrow column when unset
    CI = "1";
    FORGE_PHASE = "package";
  };

  postConfigure = ''
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist
    (cd electron-dist && zip -0Xqr ../electron.zip .)
    rm -r electron-dist

    # Make @electron/packager use this Electron rather than downloading one.
    substituteInPlace node_modules/@electron/packager/dist/packager.js \
      --replace-fail 'await this.getElectronZipPath(downloadOpts)' '"electron.zip"'
  '';

  # Skips upstream's `prepare`, which type-checks and builds the pkg helper.
  buildPhase = ''
    runHook preBuild
    npx electron-forge package
    npm prune --omit=dev --offline
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Only better-sqlite3's host prebuild is used; the bare-* modules' are
    # optional and for runtimes this app never starts.
    find node_modules -type d -name prebuilds ! -path '*/better-sqlite3/*' -prune -exec rm -rf {} +
    find node_modules/better-sqlite3/prebuilds -type f \
      ! -name 'linux-${
      if stdenv.hostPlatform.isAarch64
      then "arm64"
      else "x64"
    }.node' -delete

    mkdir -p $out/share/patreon-dl-gui $out/libexec
    cp -r out/*/resources $out/share/patreon-dl-gui/resources
    # undici and patreon-dl are externalised from the Vite bundle and resolved
    # from beside app.asar at runtime.
    cp -r node_modules $out/share/patreon-dl-gui/resources/node_modules

    install -Dm644 src/resources/*.js -t $out/share/patreon-dl-gui/embed
    makeWrapper ${lib.getExe nodejs} $out/libexec/patreon-dl-embed \
      --add-flags $out/share/patreon-dl-gui/embed/patreon-dl-embed.js \
      --set NODE_PATH $out/share/patreon-dl-gui/resources/node_modules

    makeWrapper ${lib.getExe electron} $out/bin/patreon-dl-gui \
      --add-flags $out/share/patreon-dl-gui/resources/app.asar \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --inherit-argv0

    icotool -x -i 1 -o icon.png assets/electron.ico
    install -Dm644 icon.png $out/share/icons/hicolor/128x128/apps/patreon-dl-gui.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "patreon-dl-gui";
      exec = "patreon-dl-gui";
      icon = "patreon-dl-gui";
      desktopName = "patreon-dl-gui";
      comment = "GUI for patreon-dl";
      categories = ["Utility" "Network"];
    })
    (makeDesktopItem {
      name = "patreon-dl-gui-server-console";
      exec = "patreon-dl-gui --server-console";
      icon = "patreon-dl-gui";
      desktopName = "patreon-dl-gui (Server Console)";
      comment = "Browse content downloaded by patreon-dl";
      categories = ["Utility"];
    })
  ];

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Graphical user interface for patreon-dl, a Patreon content downloader";
    homepage = "https://github.com/patrickkfkan/patreon-dl-gui";
    changelog = "https://github.com/patrickkfkan/patreon-dl-gui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "patreon-dl-gui";
    platforms = electron.meta.platforms;
  };
})

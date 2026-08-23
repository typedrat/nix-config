{
  lib,
  stdenv,
  python3Packages,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
  runCommand,
  build123d,
  nix-update-script,
}: let
  version = "0.12.0";

  src = fetchFromGitHub {
    owner = "yeicor-3d";
    repo = "yet-another-cad-viewer";
    tag = "v${version}";
    hash = "sha256-+4QjrUwr9HnN9DFxN42+jE7vXLpd34EL7cG703r9kLQ=";
  };

  # three-orientation-gizmo is locked to a branch tarball rather than a release.
  # prefetch-yarn-deps turns any github.com archive URL back into a git fetch and
  # resolves the trailing path component as a rev, so it looks for a tag named
  # "master" and finds none. Naming the commit fixes the lookup and, incidentally,
  # stops the dependency from drifting whenever that branch moves.
  yarnLock =
    runCommand "yacv-server-yarn.lock" {}
    ''
      substitute ${src}/yarn.lock $out --replace-fail \
        'https://github.com/jrj2211/three-orientation-gizmo/archive/master.tar.gz#75e1107d80e70ea8400e4cbe1cc33c19479c9baa' \
        'https://codeload.github.com/jrj2211/three-orientation-gizmo/tar.gz/000281f0559c316f72cdd23a1885d63ae6901095'
    '';

  # The wheel ships the viewer as a prebuilt bundle. Its hatchling hook would
  # otherwise shell out to yarn during the Python build, which cannot reach the
  # network; building it here first makes the hook take its already-built path.
  frontend = stdenv.mkDerivation {
    pname = "yacv-frontend";
    inherit version src;

    offlineCache = fetchYarnDeps {
      inherit yarnLock;
      hash = "sha256-YZuqo9Y2JlujzoFhTceK+ukea/hN9e3XkErGi/vSU6k=";
    };

    # yarnConfigHook insists the lockfile in the tree matches the one the offline
    # cache was built from.
    postPatch = ''
      cp ${yarnLock} yarn.lock
    '';

    nativeBuildInputs = [
      yarnConfigHook
      yarnBuildHook
      nodejs
    ];

    # The flag upstream uses for the embedded copy: it drops the pyodide and
    # monaco-editor bundles, which only the standalone web build needs.
    env.YACV_SMALL_BUILD = "true";

    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
  python3Packages.buildPythonPackage {
    pname = "yacv-server";
    inherit version src;
    pyproject = true;

    postPatch = ''
      cp -r ${frontend} yacv_server/frontend
      chmod -R u+w yacv_server/frontend
    '';

    build-system = with python3Packages; [
      hatchling
    ];

    dependencies = [
      build123d
      python3Packages.pillow
      python3Packages.pygltflib
    ];

    # Importing the package starts the viewer's HTTP server as a side effect.
    env.YACV_DISABLE_SERVER = "1";

    pythonImportsCheck = [
      "yacv_server"
    ];

    # Without --flake, nix-update resolves this file to its store path and then
    # fails to `git diff` it against the working tree. The offlineCache hash is
    # not something nix-update tracks, so it needs updating by hand.
    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "Web-based viewer for build123d and CadQuery models";
      homepage = "https://github.com/yeicor-3d/yet-another-cad-viewer";
      changelog = "https://github.com/yeicor-3d/yet-another-cad-viewer/releases/tag/v${version}";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [];
      platforms = lib.platforms.linux;
    };
  }

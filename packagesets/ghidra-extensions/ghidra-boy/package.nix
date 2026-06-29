{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
  ghidra,
}: let
  # Upstream GhidraBoy (Gekkio) only targets Ghidra 11. rrockru's PR #18
  # refactors the loader into version-specific source sets (src/ghidra11,
  # src/ghidra12) and adds a HashBridge abstraction so the extension builds
  # against Ghidra 12 too. nixpkgs ghidra is now 12.x, so we build straight from
  # the PR branch rather than upstream. The pinned rev + SRI hash below make this
  # exactly as trustworthy as any other fetchFromGitHub source.
  #
  # Based on the 20250830 release; rev is the PR #18 head.
  version = "20250830-unstable-2026-02-01";

  src = fetchFromGitHub {
    owner = "rrockru";
    repo = "GhidraBoy";
    rev = "76b3e26d3fd71d925e7f7dec3f305c41ea875348";
    hash = "sha256-H2vKFxeKYDuQGUX5017rXwfIXuMCcvgFncpDd76RQXs=";
  };

  self = buildGhidraExtension {
    pname = "ghidra-boy";
    inherit version src;

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    # GhidraBoy ships its own Gradle build rather than Ghidra's standard
    # `buildExtension` task: it produces the extension zip via a `zip` task under
    # build/distributions, and locates Ghidra through the `ghidra.dir` property
    # (or the GHIDRA_INSTALL_DIR env var) instead of `-PGHIDRA_INSTALL_DIR`.
    gradleBuildTask = "zip";
    gradleFlags = ["-Pghidra.dir=${ghidra}/lib/ghidra"];

    # The build helper's preBuild writes a stray settings.gradle next to the
    # project's settings.gradle.kts, which Gradle 9 refuses to load. Drop it and
    # let settings.gradle.kts (which already names the project "GhidraBoy") win.
    preBuild = ''
      rm -f settings.gradle
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/ghidra/Ghidra/Extensions
      unzip -d $out/lib/ghidra/Ghidra/Extensions build/distributions/*.zip

      # Prevent attempted creation of plugin lock files in the Nix store.
      for i in $out/lib/ghidra/Ghidra/Extensions/*; do
        touch "$i/.dbDirLock"
      done

      runHook postInstall
    '';

    # The zip task ships the SLEIGH language as source (.slaspec/.sinc) only.
    # Ghidra would otherwise compile it to .sla on first use, writing next to the
    # source — which fails in the read-only Nix store. Pre-compile here so the
    # .sla is part of the package.
    postInstall = ''
      langDir=$out/lib/ghidra/Ghidra/Extensions/GhidraBoy/data/languages
      for slaspec in "$langDir"/*.slaspec; do
        echo "Pre-compiling SLEIGH: $slaspec"
        ${ghidra}/bin/ghidra-sleigh "$slaspec"
      done
      # Fail loudly if no .sla was produced, rather than shipping source-only.
      if ! ls "$langDir"/*.sla >/dev/null 2>&1; then
        echo "ERROR: SLEIGH pre-compilation produced no .sla files" >&2
        exit 1
      fi
    '';

    meta = {
      description = "Ghidra extension adding Sharp SM83 / Game Boy processor support and a ROM loader";
      homepage = "https://github.com/Gekkio/GhidraBoy";
      license = lib.licenses.asl20;
    };
  };
in
  self

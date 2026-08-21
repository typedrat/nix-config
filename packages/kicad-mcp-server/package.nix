{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
  makeWrapper,
  kicad,
  kicad-skip,
  freerouting,
  jre,
  nix-update-script,
}: let
  # Qualified rather than `with ps;`: `with` loses to the function arguments, so
  # a bare `kicad` here would resolve to the top-level KiCAD, not the SWIG bindings.
  pythonEnv = python3.withPackages (ps: [
    ps.kicad # pcbnew SWIG bindings
    ps.kicad-python # IPC backend (kipy)
    kicad-skip
    ps.pillow
    ps.cairosvg
    ps.colorlog
    ps.pydantic
    ps.requests
    ps.python-dotenv
    ps.typing-extensions
  ]);

  # KiCAD keys its library env vars on the major version and only exports them
  # from inside its own wrapper. Unset, the server's library lookups — and the
  # KICAD<n>_*_DIR references in sym-lib-table/fp-lib-table — fall through to
  # /usr/share/kicad and resolve to nothing.
  kicadMajor = lib.versions.major kicad.version;

  # PCM-installed libraries live under the user settings directory, which KiCAD
  # names after the release series.
  kicadSeries = lib.versions.majorMinor kicad.version;
in
  buildNpmPackage (finalAttrs: {
    pname = "kicad-mcp-server";
    version = "2.7.0";

    src = fetchFromGitHub {
      owner = "mixelpixx";
      repo = "KiCAD-MCP-Server";
      tag = "v${finalAttrs.version}";
      hash = "sha256-faCTkstk6LEm9qctoRObtlATUOW8JNQ645LepAFsgMI=";
    };

    npmDepsHash = "sha256-LBUZmYzYnaVyuU0/fwy6t3yoIIb8Qbve/mF/Fv6Y6qg=";

    nativeBuildInputs = [
      makeWrapper
    ];

    # tsc is run by the default npm build script
    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/kicad-mcp-server
      cp -r dist $out/lib/kicad-mcp-server/
      cp -r node_modules $out/lib/kicad-mcp-server/
      cp -r python $out/lib/kicad-mcp-server/
      cp -r config $out/lib/kicad-mcp-server/
      cp package.json $out/lib/kicad-mcp-server/

      # The 3rd-party dir goes through --run because --set-default shell-quotes
      # its value, which would leave $HOME literal.
      makeWrapper ${lib.getExe nodejs} $out/bin/kicad-mcp-server \
        --add-flags "$out/lib/kicad-mcp-server/dist/index.js" \
        --prefix PATH : ${lib.makeBinPath [jre]} \
        --set KICAD_PYTHON ${lib.getExe' pythonEnv "python3"} \
        --set-default PYTHONPATH ${pythonEnv}/${python3.sitePackages} \
        --set-default KICAD${kicadMajor}_SYMBOL_DIR ${kicad.libraries.symbols}/share/kicad/symbols \
        --set-default KICAD${kicadMajor}_FOOTPRINT_DIR ${kicad.libraries.footprints}/share/kicad/footprints \
        --set-default FREEROUTING_JAR ${freerouting}/share/freerouting/freerouting-executable.jar \
        --run 'export KICAD${kicadMajor}_3RD_PARTY="''${KICAD${kicadMajor}_3RD_PARTY:-''${XDG_DATA_HOME:-$HOME/.local/share}/kicad/${kicadSeries}/3rdparty}"'

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "AI-assisted PCB design with KiCAD via Model Context Protocol";
      homepage = "https://github.com/mixelpixx/KiCAD-MCP-Server";
      license = lib.licenses.mit;
      mainProgram = "kicad-mcp-server";
      platforms = lib.platforms.linux;
    };
  })

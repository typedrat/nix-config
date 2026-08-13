{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
  makeBinaryWrapper,
  kicad-skip,
  nix-update-script,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      kicad # pcbnew SWIG bindings
      kicad-python # IPC backend (kipy)
      kicad-skip
      pillow
      cairosvg
      colorlog
      pydantic
      requests
      python-dotenv
      typing-extensions
    ]);
in
  buildNpmPackage (finalAttrs: {
    pname = "kicad-mcp-server";
    version = "2.6.0";

    src = fetchFromGitHub {
      owner = "mixelpixx";
      repo = "KiCAD-MCP-Server";
      tag = "v${finalAttrs.version}";
      hash = "sha256-vEQMbF5kU5bAhRlaC8TMkRfZJW06GQkUBZOHfkxc+Pg=";
    };

    npmDepsHash = "sha256-QlrIhfin80CpTaEKs7ujqW4m1rF/ENUY0aEdD8SBMHc=";

    nativeBuildInputs = [
      makeBinaryWrapper
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

      makeBinaryWrapper ${lib.getExe nodejs} $out/bin/kicad-mcp-server \
        --add-flags "$out/lib/kicad-mcp-server/dist/index.js" \
        --set KICAD_PYTHON ${lib.getExe' pythonEnv "python3"}

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

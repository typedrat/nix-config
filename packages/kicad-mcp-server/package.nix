{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  python3,
  nodejs,
  makeBinaryWrapper,
  kicad-skip,
}: let
  pythonEnv = python3.withPackages (ps:
    with ps; [
      kicad # pcbnew SWIG bindings
      # TODO: re-enable when protoletariat is fixed (https://github.com/NixOS/nixpkgs/issues/498062)
      # kicad-python # IPC backend (kipy)
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
  buildNpmPackage (_finalAttrs: {
    pname = "kicad-mcp-server";
    version = "0-unstable-2025-12-01";

    src = fetchFromGitHub {
      owner = "mixelpixx";
      repo = "KiCAD-MCP-Server";
      rev = "d34c1a6f7ea137cc9cf7b18b2839b5ac2c86e75e";
      hash = "sha256-HSvF08Tq0F1s2nb2BjwnzYle1k+K/hi/1g5q5pEBKls=";
    };

    npmDepsHash = "sha256-nz73qj8CK2LyFixoF14ET2wq407YyuJUw/4VTDc80cQ=";

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
      cp package.json $out/lib/kicad-mcp-server/

      makeBinaryWrapper ${lib.getExe nodejs} $out/bin/kicad-mcp-server \
        --add-flags "$out/lib/kicad-mcp-server/dist/index.js" \
        --set KICAD_PYTHON ${lib.getExe' pythonEnv "python3"}

      runHook postInstall
    '';

    meta = {
      description = "AI-assisted PCB design with KiCAD via Model Context Protocol";
      homepage = "https://github.com/mixelpixx/KiCAD-MCP-Server";
      license = lib.licenses.mit;
      mainProgram = "kicad-mcp-server";
      platforms = lib.platforms.linux;
    };
  })

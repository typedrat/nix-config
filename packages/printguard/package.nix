{
  lib,
  python3Packages,
  fetchFromGitHub,
  buildNpmPackage,
  pycentauri,
  # Named to avoid colliding with the top-level `onnxruntime` (the C++
  # library): callPackage auto-wires any parameter matching a top-level pkgs
  # attribute ahead of its own default, so a plain `onnxruntime` argument here
  # would silently bind to that unrelated package instead of the Python one.
  printguardOnnxruntime ? python3Packages.onnxruntime,
  nix-update-script,
}:
python3Packages.buildPythonApplication rec {
  pname = "printguard";
  version = "2.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "oliverbravery";
    repo = "PrintGuard";
    tag = "v${version}";
    hash = "sha256-Wm/tzjm96SMUA860YzaFqXHOpZzOB/6LVa6eO35OApg=";
  };

  frontend = buildNpmPackage {
    pname = "printguard-web";
    inherit version src;

    sourceRoot = "${src.name}/web";

    npmDepsHash = "sha256-Fyd64kSJ8g+R2WVBYUr0wTk0EZoP3sERM+yf8b7J90Y=";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/* $out/
      runHook postInstall
    '';
  };

  # The hub binds every interface unconditionally. Honouring HOST lets the
  # service listen on loopback and be reached only through Traefik.
  postPatch = ''
    substituteInPlace printguard/server/app.py \
      --replace-fail \
        'host="0.0.0.0"' \
        'host=os.environ.get("HOST", "0.0.0.0")'

    # Store files have mtime = epoch and zipfile rejects pre-1980 timestamps,
    # so the source bundle the hub builds at startup aborts before it binds.
    substituteInPlace printguard/pysrc.py \
      --replace-fail \
        'zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED)' \
        'zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED, strict_timestamps=False)'
  '';

  build-system = with python3Packages; [
    hatchling
  ];

  # onnxruntime-ep-openvino is an optional ONNX execution provider that is not
  # in nixpkgs; inference.py loads it opportunistically and falls back without
  # it.
  pythonRemoveDeps = [
    "onnxruntime-ep-openvino"
  ];

  # Upstream wants >=2.14.2 and nixpkgs is a couple of releases behind.
  # pythonImportsCheck covers whether that actually matters.
  pythonRelaxDeps = [
    "pydantic-settings"
  ];

  dependencies = with python3Packages;
    [
      ai-edge-litert
      aiomqtt
      av
      fastapi
      fastmcp
      httpx
      ml-dtypes
      numpy
      packaging
      paho-mqtt
      pydantic-settings
      pyprusalink
      starlette
      uvicorn
      wasmtime
    ]
    ++ [
      pycentauri
      printguardOnnxruntime
    ];

  # models/ is committed upstream but excluded from the wheel, which only ships
  # the printguard package directory.
  postInstall = ''
    mkdir -p $out/share/printguard
    cp -r ${frontend} $out/share/printguard/web
    cp -r models $out/share/printguard/models

    # The desktop entry point needs the pywebview/pystray extra, which is not
    # installed here.
    rm -f $out/bin/printguard-desktop
  '';

  pythonImportsCheck = [
    "printguard"
    "printguard.server.app"
    "printguard.server.inference"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake" "--subpackage" "frontend"];
  };

  meta = {
    description = "Real-time 3D print failure detection";
    homepage = "https://github.com/oliverbravery/PrintGuard";
    license = lib.licenses.gpl2Only;
    mainProgram = "printguard";
    platforms = lib.platforms.linux;
  };
}

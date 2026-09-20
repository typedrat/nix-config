{
  lib,
  python3,
  fetchFromGitHub,
  nix-update-script,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "comfy-cli";
  version = "1.20.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Comfy-Org";
    repo = "comfy-cli";
    rev = "v${version}";
    hash = "sha256-G8cTlCvqUVuxMm9xAj+h8nCQRZWA0rzafN6MW4caZbc=";
  };

  nativeBuildInputs = with python3.pkgs; [
    pythonRelaxDepsHook
  ];

  build-system = [
    python3.pkgs.setuptools
  ];

  dependencies = with python3.pkgs; [
    blake3
    charset-normalizer
    click
    cookiecutter
    gitpython
    httpx
    imageio-ffmpeg
    mixpanel
    packaging
    pathspec
    posthog
    psutil
    pyyaml
    questionary
    requests
    rich
    ruff
    semver
    tomlkit
    typer
    typing-extensions
    uv
    websocket-client
  ];

  optional-dependencies = with python3.pkgs; {
    dev = [
      pre-commit
      pytest
      pytest-cov
      ruff
    ];
  };

  pythonImportsCheck = [
    "comfy_cli"
  ];

  # blake3 is a declared dependency nothing in the tree imports, so the
  # >=1.0.9 floor buys nothing over nixpkgs' 1.0.8.
  pythonRelaxDeps = ["blake3" "mixpanel"];

  postFixup = ''
    rm $out/bin/comfy-cli $out/bin/comfycli
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Command Line Interface for Managing ComfyUI";
    homepage = "https://github.com/Comfy-Org/comfy-cli";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [typedrat];
    mainProgram = "comfy";
  };
}

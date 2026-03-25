{
  lib,
  python3,
  fetchFromGitHub,
  nix-update-script,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "comfy-cli";
  version = "1.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Comfy-Org";
    repo = "comfy-cli";
    rev = "v${version}";
    hash = "sha256-gk1WnsXVEW0AHFYJP/62EtthBwigQzVyIqIBDnzdAkg=";
  };

  build-system = [
    python3.pkgs.setuptools
  ];

  dependencies = with python3.pkgs; [
    charset-normalizer
    click
    cookiecutter
    gitpython
    httpx
    mixpanel
    packaging
    pathspec
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

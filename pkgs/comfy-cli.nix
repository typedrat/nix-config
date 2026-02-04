{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "comfy-cli";
  version = "1.5.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Comfy-Org";
    repo = "comfy-cli";
    rev = "v${version}";
    hash = "sha256-kFYJgF/H0mP0Y/9V0cnll7/IGRdArWqCpQMinynvTVo=";
  };

  build-system = [
    python3.pkgs.setuptools
  ];

  nativeBuildInputs = [
    python3.pkgs.pythonRelaxDepsHook
  ];

  # comfy-cli pins click<=8.1.8 due to old typer incompatibility (github.com/Comfy-Org/comfy-cli/issues/266)
  # but typer 0.16.0+ works with newer click, and nixpkgs has typer 0.21.0
  pythonRelaxDeps = [ "click" ];

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

  meta = {
    description = "Command Line Interface for Managing ComfyUI";
    homepage = "https://github.com/Comfy-Org/comfy-cli";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ typedrat ];
    mainProgram = "comfy";
  };
}

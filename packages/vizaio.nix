{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "vizaio";
  version = "0.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "raman325";
    repo = "vizaio";
    tag = "v${finalAttrs.version}";
    hash = "sha256-LQkhwZ9FZSM9ll2U75VF8uDTaCiREUkFD2JBYGR4IJU=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    aiohttp
    # `cli` and `discovery` extras; upstream keeps them optional so the Home
    # Assistant integration doesn't inherit rich's version constraints.
    platformdirs
    rich
    tomlkit
    typer
    zeroconf
  ];

  nativeCheckInputs = with python3Packages; [
    aioresponses
    pytest-asyncio
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "vizaio"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Async Python client and CLI for Vizio SmartCast devices";
    homepage = "https://github.com/raman325/vizaio";
    changelog = "https://github.com/raman325/vizaio/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "vizaio";
    maintainers = [];
  };
})

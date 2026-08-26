{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "pycentauri";
  version = "0.9.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "brandonrthomas";
    repo = "pycentauri";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kO3CMMHsElQBkL7zm/Z5l4eOVef1Mbs7bf0AS1lVw6E=";
  };

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    httpx
    paho-mqtt
    pydantic
    typer
    typing-extensions
    websockets
  ];

  pythonImportsCheck = [
    "pycentauri"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Local-network client for Elegoo Centauri Carbon 3D printers";
    homepage = "https://github.com/brandonrthomas/pycentauri";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
})

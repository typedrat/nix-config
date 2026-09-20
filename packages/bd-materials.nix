{
  lib,
  python3Packages,
  fetchFromGitHub,
  threejs-materials,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "bd-materials";
  version = "0.2.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bernhard-42";
    repo = "bd_materials";
    tag = "v${finalAttrs.version}";
    hash = "sha256-R0hkxJNJdEa59TjnaFMxQyZvaxQSNqDZoxVYKRYkA7E=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  # Pinned to the 24.8 series for the color tables, which 25.x leaves alone.
  pythonRelaxDeps = [
    "webcolors"
  ];

  dependencies = [
    threejs-materials
    python3Packages.webcolors
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "bd_materials"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Engineering materials, finishes and PBR looks for build123d";
    homepage = "https://github.com/bernhard-42/bd_materials";
    # Upstream ships no license of any kind, on GitHub or in the release.
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [];
  };
})

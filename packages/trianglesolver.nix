{
  lib,
  python3Packages,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "trianglesolver";
  version = "1.2";
  pyproject = true;

  # The GitHub repo carries no tags, so the sdist is the only versioned source.
  src = python3Packages.fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-SvGKreV51cDWQ4mz5lrq8Gz/JjGXYszYWeMmhVmnauo=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  pythonImportsCheck = [
    "trianglesolver"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Solve a triangle from any three of its sides and angles";
    homepage = "https://github.com/sbyrnes321/trianglesolver";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [];
  };
})

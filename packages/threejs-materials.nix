{
  lib,
  python3Packages,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "threejs-materials";
  version = "1.2.3";
  pyproject = true;

  # The v1.2.3 tag sits two commits behind the release and still carries the
  # 1.2.2 version string, so the sdist is the only tree that matches.
  src = python3Packages.fetchPypi {
    pname = "threejs_materials";
    inherit (finalAttrs) version;
    hash = "sha256-ids0HasKAideWX76l82XmCMHRlS8ori6MEKjN4rLmQE=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  # Upstream caps pillow below 12.3 to match its own CI pin.
  pythonRelaxDeps = [
    "pillow"
  ];

  # numpy is imported at module scope by convert.py but missing from the
  # project metadata.
  dependencies = with python3Packages; [
    numpy
    pillow
    platformdirs
    pygltflib
    requests
  ];

  pythonImportsCheck = [
    "threejs_materials"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "PBR materials converted to three.js MeshPhysicalMaterial JSON";
    homepage = "https://github.com/bernhard-42/threejs-materials";
    changelog = "https://github.com/bernhard-42/threejs-materials/blob/v${finalAttrs.version}/Changes.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
  };
})

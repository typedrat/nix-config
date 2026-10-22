{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "java-stubs-converted-strings";
  version = "0.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jstasiak";
    repo = "jpype-stubs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PK3uzHn3E6mHTzHnUXPiCSwHdETUDYZ4Ot9NKbu4uZk=";
  };

  # The repo builds two distributions; the plain java-stubs one sits at the
  # root.
  sourceRoot = "${finalAttrs.src.name}/java-stubs-converted-strings";

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    jpype1
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "JPype java.* type stubs with Java strings converted to Python strings";
    homepage = "https://github.com/jstasiak/jpype-stubs";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [];
  };
})

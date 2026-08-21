{
  lib,
  python3Packages,
  fetchFromGitHub,
  cadquery-ocp-novtk,
  cadquery-ocp-proxy,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "ocpsvg";
  version = "0.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "snoyer";
    repo = "ocpsvg";
    tag = finalAttrs.version;
    hash = "sha256-/E5z9LXvxtoXxZO0JyeXTm4BUG9CcPDT6UnkX4R6tEA=";
  };

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  # The proxy carries only the version constraint; the bindings themselves come
  # from the novtk build.
  dependencies = [
    cadquery-ocp-novtk
    cadquery-ocp-proxy
    python3Packages.svgelements
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "ocpsvg"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "SVG to OpenCASCADE geometry conversion";
    homepage = "https://github.com/snoyer/ocpsvg";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
  };
})

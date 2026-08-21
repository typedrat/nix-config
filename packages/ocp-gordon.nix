{
  lib,
  python3Packages,
  fetchFromGitHub,
  cadquery-ocp-novtk,
  cadquery-ocp-proxy,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "ocp-gordon";
  version = "0.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "gongfan99";
    repo = "ocp_gordon";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FcRQ/7A49LbbtBF5uC1MRa/4E4KlkxKX9AhU4B4QAe8=";
  };

  # setuptools_scm derives the version from git metadata that the tarball drops.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  # The proxy carries only the version constraint; the bindings themselves come
  # from the novtk build.
  dependencies =
    [
      cadquery-ocp-novtk
      cadquery-ocp-proxy
    ]
    ++ (with python3Packages; [
      numpy
      scipy
    ]);

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "ocp_gordon"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Gordon surface interpolation with B-splines on OpenCASCADE geometry";
    homepage = "https://github.com/gongfan99/ocp_gordon";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
  };
})

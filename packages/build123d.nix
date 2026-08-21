{
  lib,
  python3Packages,
  fetchFromGitHub,
  cadquery-ocp-novtk,
  lib3mf-python,
  ocp-gordon,
  ocpsvg,
  trianglesolver,
  nix-update-script,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "build123d";
  version = "0.11.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "gumyr";
    repo = "build123d";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Ua5njNi82iMJQciPSeg+fkdQlnVtLPaNW3JDjiJDDNo=";
  };

  # setuptools_scm derives the version from git metadata that the tarball drops.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  # build123d pins webcolors to the 24.8 series; the colour tables and the
  # name_to_rgb/rgb_to_name surface it uses are unchanged in 25.x.
  pythonRelaxDeps = [
    "webcolors"
  ];

  # ImportSTEP downloads a sample assembly in setUpClass, which fails the whole
  # class in the sandbox even though only one of its tests reads the file.
  postPatch = ''
    substituteInPlace tests/test_importers.py \
      --replace-fail "urllib.request.urlretrieve(url, file_path)" "pass"
  '';

  dependencies =
    [
      cadquery-ocp-novtk
      lib3mf-python
      ocp-gordon
      ocpsvg
      trianglesolver
    ]
    ++ (with python3Packages; [
      anytree
      ezdxf
      ipython
      numpy
      requests
      scikit-learn
      scipy
      svgpathtools
      sympy
      typing-extensions
      webcolors
    ]);

  # Deliberately no pytest-xdist: pytestCheckHook would then hand pytest a
  # --numprocesses, and several tests round-trip through a shared "test.step" in
  # the working directory, so they delete each other's files at random.
  nativeCheckInputs = with python3Packages; [
    packaging
    pytestCheckHook
  ];

  disabledTests = [
    # The one test that actually needs the sample assembly downloaded above.
    "test_assembly_with_oriented_parts"
  ];

  disabledTestPaths = [
    # Needs VTK, which the novtk bindings deliberately leave out.
    "tests/test_direct_api/test_vtk_poly_data.py"
    # Needs a live Jupyter kernel.
    "tests/test_direct_api/test_jupyter.py"
  ];

  pythonImportsCheck = [
    "build123d"
  ];

  # Without --flake, nix-update resolves this file to its store path and then
  # fails to `git diff` it against the working tree.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = {
    description = "Python CAD programming library built on OpenCASCADE";
    homepage = "https://github.com/gumyr/build123d";
    changelog = "https://github.com/gumyr/build123d/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [];
    platforms = lib.platforms.linux;
  };
})

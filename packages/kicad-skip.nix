{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "kicad-skip";
  version = "0.2.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "psychogenic";
    repo = "kicad-skip";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PFrfaIyh8y9dZNw4oP4IBBIM7PsA5znkDbmMfo8hFT8=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    sexpdata
  ];

  pythonImportsCheck = [
    "skip"
  ];

  meta = {
    description = "KiCAD s-expression schematic/layout file manipulation";
    homepage = "https://github.com/psychogenic/kicad-skip";
    license = lib.licenses.lgpl21Only;
    maintainers = with lib.maintainers; [];
  };
})

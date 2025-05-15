{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonPackage rec {
  pname = "kicad-skip";
  version = "0.2.5";

  src = fetchFromGitHub {
    owner = "psychogenic";
    repo = "kicad-skip";
    rev = "v${version}";
    hash = "sha256-PFrfaIyh8y9dZNw4oP4IBBIM7PsA5znkDbmMfo8hFT8=";
  };

  format = "pyproject";

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    sexpdata
  ];

  doCheck = false;

  meta = with lib; {
    description = "A friendly way to skip the drudgery and manipulate kicad 7+ s-expression schematic, netlist and PCB files";
    homepage = "https://github.com/psychogenic/kicad-skip";
    license = licenses.lgpl2Plus;
    platforms = platforms.all;
  };
}

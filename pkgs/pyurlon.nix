{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonPackage rec {
  pname = "pyurlon";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "adamws";
    repo = "pyurlon";
    rev = "v${version}";
    hash = "sha256-hplWKoXl//+7VfZ4gMRRwInlDCjqFf0HJ2FIuFK2lWE=";
  };

  format = "pyproject";

  nativeBuildInputs = with python3Packages; [
    hatchling
  ];

  doCheck = false;

  meta = with lib; {
    description = "Python port of https://github.com/cerebral/urlon javascript package";
    homepage = "https://github.com/adamws/pyurlon";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

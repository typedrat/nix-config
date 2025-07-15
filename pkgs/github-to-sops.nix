{
  lib,
  python3Packages,
  fetchPypi,
}:
python3Packages.buildPythonPackage rec {
  pname = "github-to-sops";
  version = "1.4.1";
  pyproject = true;

  src = fetchPypi {
    pname = "github_to_sops";
    inherit version;
    hash = "sha256-CenUEm+SHdFbQ1cXOZVbHelKbyPtrNDYn+tKUYPIfcE=";
  };

  build-system = with python3Packages; [
    setuptools
  ];

  meta = with lib; {
    description = "Fearlessly share infra secrets in git by combining sops + github ssh keys";
    homepage = "https://github.com/tarasglek/github-to-sops";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

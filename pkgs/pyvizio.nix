{
  lib,
  python3Packages,
  fetchPypi,
}:
python3Packages.buildPythonPackage rec {
  pname = "pyvizio";
  version = "0.1.61";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-AtqMWe2zgRqOp5S9oKq7keHNHM8pnTmV1mfGiVzygTc=";
  };

  dependencies = with python3Packages; [
    aiohttp
    click
    jsonpickle
    requests
    tabulate
    xmltodict
    zeroconf
  ];

  doCheck = false;

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  meta = with lib; {
    description = "Python client for Vizio SmartCast";
    homepage = "https://github.com/raman325/pyvizio";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

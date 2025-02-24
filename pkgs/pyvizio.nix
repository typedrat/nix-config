{pkgs, ...}: let
  python3Packages = pkgs.python3Packages;
  fetchPypi = pkgs.fetchPypi;
in
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

    meta = {
      description = "Python client for Vizio SmartCast";
      homepage = "https://github.com/raman325/pyvizio";
    };
  }

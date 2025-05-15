{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonPackage rec {
  pname = "hatch-kicad";
  version = "0.4.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "adamws";
    repo = "hatch-kicad";
    rev = "v${version}";
    hash = "sha256-UmqmOR1BYOf4VIx/rYOvCu5+61U4YwGBBTcCYztNwq0=";
  };

  nativeBuildInputs = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  propagatedBuildInputs = with python3Packages; [
    hatchling
  ];

  doCheck = false;

  meta = with lib; {
    description = "A hatch plugin for packaging KiCad plugins";
    homepage = "https://github.com/adamws/hatch-kicad";
    license = licenses.mit;
    platforms = platforms.all;
  };
}

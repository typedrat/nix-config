{
  lib,
  python3Packages,
  fetchFromGitHub,
  hatch-kicad,
  kicad-skip,
  pyurlon,
}:
python3Packages.buildPythonPackage rec {
  pname = "kbplacer";
  version = "0.13";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "adamws";
    repo = "kicad-kbplacer";
    rev = "v${version}";
    hash = "sha256-SMRPzuZTVnMMgpYljgz3uX6pmHAQ7qWhbZlX8IcpNqA=";
  };

  postPatch = ''
    substituteInPlace tools/layout2openscad.py \
        --replace-fail 'from solid' 'from solid2'
  '';

  build-system = with python3Packages; [
    hatchling
    hatch-kicad
    hatch-fancy-pypi-readme
    hatch-vcs
  ];

  nativeBuildInputs = with python3Packages; [
    wrapPython
  ];

  dependencies = with python3Packages; [
    kicad
    wxpython
    colormath
    drawsvg
    pyyaml
    shapely
    solidpython2
    kicad-skip
    pyurlon
  ];

  postInstall = ''
    for script in $src/tools/*.py; do
      filename=$(basename "$script" .py)
      tmpfile=$(mktemp)
      echo "#!/usr/bin/python" > "$tmpfile"
      cat "$script" >> "$tmpfile"
      install -Dm755 "$tmpfile" "$out/bin/$filename"
      rm "$tmpfile"
    done
  '';
  doCheck = false;

  meta = with lib; {
    description = "KiCad plugin for automatic keyboard's key placement";
    homepage = "https://github.com/adamws/kicad-kbplacer";
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}

{
  lib,
  fetchFromGitHub,
}: let
  version = "0.26.1";
in {
  inherit version;

  src = fetchFromGitHub {
    owner = "Donkie";
    repo = "Spoolman";
    tag = "v${version}";
    hash = "sha256-tBHU4WvknqkRNxlQJ/wuzM3mrQVyMS3eED1Kimi6rsU=";
  };

  # Lives beside the version so the update script, which edits only this file,
  # refreshes it too.
  npmDepsHash = "sha256-DYUwz3rOdnah3EUBM7dciCdEsRlZG9ijoHiPWLIdRuc=";

  meta = {
    description = "Keep track of your inventory of 3D-printer filament spools";
    homepage = "https://github.com/Donkie/Spoolman";
    license = lib.licenses.mit;
    mainProgram = "spoolman";
  };
}

{
  lib,
  fetchFromGitHub,
}: let
  version = "0.27.1";
in {
  inherit version;

  src = fetchFromGitHub {
    owner = "Donkie";
    repo = "Spoolman";
    tag = "v${version}";
    hash = "sha256-DR5m+aQCTYgqgCAqJPd6yx2t9tkf6je7Z04RO8wi2GQ=";
  };

  # Lives beside the version so the update script, which edits only this file,
  # refreshes it too.
  npmDepsHash = "sha256-7/JVwL1E7A9KgWFgtH5sq/OgmO3QwaoPab7ik0EPA9w=";

  meta = {
    description = "Keep track of your inventory of 3D-printer filament spools";
    homepage = "https://github.com/Donkie/Spoolman";
    license = lib.licenses.mit;
    mainProgram = "spoolman";
  };
}

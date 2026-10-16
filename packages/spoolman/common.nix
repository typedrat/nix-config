{
  lib,
  fetchFromGitHub,
}: let
  version = "0.27.0";
in {
  inherit version;

  src = fetchFromGitHub {
    owner = "Donkie";
    repo = "Spoolman";
    tag = "v${version}";
    hash = "sha256-vaN2VgTj8JJmJl7KQfvLCq4kV1mfJs77m60xRljNk9s=";
  };

  # Lives beside the version so the update script, which edits only this file,
  # refreshes it too.
  npmDepsHash = "sha256-JCyDOhgaKdMnnhbuOjmI/emqYyve/c0i+fvRJP7lkng=";

  meta = {
    description = "Keep track of your inventory of 3D-printer filament spools";
    homepage = "https://github.com/Donkie/Spoolman";
    license = lib.licenses.mit;
    mainProgram = "spoolman";
  };
}

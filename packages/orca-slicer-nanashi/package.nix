{
  fetchFromGitHub,
  orca-slicer,
  nix-update-script,
}:
# NanashiTheNameless maintains a rolling nightly of OrcaSlicer whose
# `Nightly-Rolling` tag always points at the tip of `main`, so pin the commit
# and let the update script follow that branch. The upstream build recipe and
# its patch set are reused wholesale; only the source is swapped.
orca-slicer.overrideAttrs (prev: {
  pname = "orca-slicer-nanashi";
  version = "Nightly-Rolling-unstable-2026-07-05";

  src = fetchFromGitHub {
    owner = "NanashiTheNameless";
    repo = "OrcaSlicer";
    rev = "124dc136ec40ec367163e184604c79891001ef6b";
    hash = "sha256-FMu0sE1uJ9ObKW2CF0W/I1MaC+J+9m73pHjcvs/PHnU=";
  };

  passthru =
    (prev.passthru or {})
    // {
      updateScript = nix-update-script {
        extraArgs = ["--flake" "--version=branch"];
      };
    };

  meta =
    prev.meta
    // {
      description = "OrcaSlicer nightly built from the NanashiTheNameless fork";
      homepage = "https://github.com/NanashiTheNameless/OrcaSlicer";
      changelog = "https://github.com/NanashiTheNameless/OrcaSlicer/releases/tag/Nightly-Rolling";
    };
})

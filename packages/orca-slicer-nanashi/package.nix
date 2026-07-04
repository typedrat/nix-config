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
  version = "Nightly-Rolling-unstable-2026-07-04";

  src = fetchFromGitHub {
    owner = "NanashiTheNameless";
    repo = "OrcaSlicer";
    rev = "bb6e25c291721b325c7f7afff8f6466a807844be";
    hash = "sha256-Isrviy/Lk9qXWMuwdx3sbePUwKtvfqDBUh435XnF84U=";
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

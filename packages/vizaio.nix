{python3Packages}:
# nixpkgs packages vizaio as a library and keeps the CLI behind its `cli`
# extra, so `vizaio` on PATH needs those promoted to runtime dependencies.
# `discovery` comes along so `vizaio discover` works without a second variant.
let
  inherit (python3Packages) vizaio toPythonApplication;
  inherit (vizaio) optional-dependencies;
in
  toPythonApplication (
    vizaio.overridePythonAttrs (old: {
      dependencies =
        old.dependencies
        ++ optional-dependencies.cli
        ++ optional-dependencies.discovery;
    })
  )

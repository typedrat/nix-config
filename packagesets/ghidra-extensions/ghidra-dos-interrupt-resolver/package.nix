{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
}: let
  # Built from typedrat/call-override, which adds typed call overrides,
  # register-pinned entry selection and merged return structs on top of
  # upstream (playday3008/GhidraDosInterruptResolver), which has no releases.
  version = "1.0.0-unstable-2026-10-22";

  src = fetchFromGitHub {
    owner = "typedrat";
    repo = "GhidraDosInterruptResolver";
    rev = "996ee1fffc57bf389fe7e2d52bef003a26090207";
    # The interrupt definitions are the rbil-yaml submodule.
    fetchSubmodules = true;
    hash = "sha256-/N8Ncsg72RGr822jr5lY1vDTLs+CdQ4jk2rRQI21yxA=";
  };

  self = buildGhidraExtension {
    pname = "ghidra-dos-interrupt-resolver";
    inherit version src;

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    # The project disables `buildExtension` in favour of its own zip task,
    # which also bundles SnakeYAML and the RBIL data into dist/.
    gradleBuildTask = "createDistribution";

    meta = {
      description = "Ghidra analyzer that resolves x86 DOS/BIOS interrupt calls using Ralf Brown's Interrupt List";
      homepage = "https://github.com/typedrat/GhidraDosInterruptResolver";
      license = lib.licenses.asl20;
    };
  };
in
  self

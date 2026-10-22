{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
  ghidra,
}: let
  version = "1.3.2-dev";

  src = fetchFromGitHub {
    owner = "typedrat";
    repo = "ghidra-snes";
    rev = "typedrat/cspec-register-conventions";
    hash = "sha256-QE1ykSACKg9VbI6shOV81/ecu5HjgNxjoDcIKQThKNw=";
  };

  self = buildGhidraExtension {
    pname = "ghidra-snes";
    inherit version src;

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    # The upstream gradle `buildExtension` task ships the SLEIGH language as
    # source (.slaspec/.sinc) only. Ghidra would otherwise compile it to .sla on
    # first use, writing next to the source — which fails in the read-only Nix
    # store. Pre-compile here so the .sla is part of the package.
    #
    # The upstream Module.manifest also declares `MODULE DEPENDENCIES:` with an
    # indented `Ghidra` line, which isn't manifest syntax. Ghidra reports each
    # bad line on stdout at startup, corrupting stdio MCP sessions (mcp-reva).
    postInstall = ''
      echo "MODULE NAME: Ghidra-SNES" > $out/lib/ghidra/Ghidra/Extensions/ghidra-snes/Module.manifest

      langDir=$out/lib/ghidra/Ghidra/Extensions/ghidra-snes/data/languages
      for slaspec in "$langDir"/*.slaspec; do
        echo "Pre-compiling SLEIGH: $slaspec"
        ${ghidra}/bin/ghidra-sleigh "$slaspec"
      done
      # Fail loudly if no .sla was produced, rather than shipping source-only.
      if ! ls "$langDir"/*.sla >/dev/null 2>&1; then
        echo "ERROR: SLEIGH pre-compilation produced no .sla files" >&2
        exit 1
      fi
    '';

    meta = {
      description = "Ghidra extension for loading and working with SNES ROMs (LoROM/HiROM loader and 65816 language)";
      homepage = "https://github.com/joshleaves/ghidra-snes";
      license = lib.licenses.mit;
    };
  };
in
  self

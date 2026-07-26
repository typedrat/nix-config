{
  lib,
  stdenvNoCC,
  fetchurl,
  writeShellApplication,
  curl,
  jq,
  gnused,
  coreutils,
}: let
  repo = "handy-computer/parakeet-unified-en-0.6b-gguf";

  # The commit `main` pointed at when this was pinned. hf-hub resolves a repo by
  # reading refs/<revision> and joining the result onto snapshots/, so the hash
  # has to be baked in rather than fetched.
  rev = "7e948f21b7bdbac698d3318db9d350f1096f3b6c";

  # Handy's bundled catalog names Q8_0 as this model's default quant, and it
  # derives the catalog entry's id and filename from that choice. Shipping any
  # other quant would leave the catalog entry showing as "not downloaded" and
  # register the file as an unrelated cache find instead.
  filename = "parakeet-unified-en-0.6b-Q8_0.gguf";

  weights = fetchurl {
    url = "https://huggingface.co/${repo}/resolve/${rev}/${filename}";
    hash = "sha256-S1C23YYr9uNGkpqvT16qzsADv6P1ZGLWyHS0HvLzh5U=";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "handy-parakeet-unified-en";
    version = "0-unstable-2026-06-28";

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/refs $out/snapshots/${rev}

      # No trailing newline: hf-hub feeds this file's contents straight into the
      # snapshot path without trimming.
      printf '%s' ${rev} > $out/refs/main

      ln -s ${weights} $out/snapshots/${rev}/${filename}

      runHook postInstall
    '';

    passthru = {
      inherit repo rev filename;

      # Where hf-hub expects this repo to sit inside the cache root, and the id
      # Handy's model registry gives the catalog entry backed by it.
      cacheDirName = "models--${builtins.replaceStrings ["/"] ["--"] repo}";
      modelId = "${repo}/${filename}";

      updateScript = lib.getExe (writeShellApplication {
        name = "handy-parakeet-unified-en-update";
        runtimeInputs = [curl jq gnused coreutils];
        text = builtins.readFile ./update.sh;
      });
    };

    meta = {
      description = "Parakeet Unified EN 0.6B speech-to-text weights, laid out as a Hugging Face cache repo for Handy";
      homepage = "https://huggingface.co/${repo}";
      license = lib.licenses.cc-by-40;
      sourceProvenance = [lib.sourceTypes.binaryBytecode];
      platforms = lib.platforms.all;
    };
  }

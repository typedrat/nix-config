{
  lib,
  python3,
  fetchFromGitHub,
  nix-update-script,
}: let
  # posthog is marked broken against mcp 2, which nixpkgs now defaults to; it
  # has no use for mcp itself, so build the closure on mcp 1.
  pythonPkgs = python3.pkgs.overrideScope (final: _prev: {mcp = final.mcp_1;});
in
  pythonPkgs.buildPythonApplication rec {
    pname = "comfy-cli";
    version = "1.23.0";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "comfy-cli";
      rev = "v${version}";
      hash = "sha256-y6HRhp3i4c5eRnhH4R4s7jkFv0r224KDmdncc+78pjM=";
    };

    nativeBuildInputs = with pythonPkgs; [
      pythonRelaxDepsHook
    ];

    # Upstream ships a placeholder version for its release pipeline to fill in,
    # and `comfy version` reads it back out of the installed metadata.
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'version = "0.0.0"' 'version = "${version}"'
    '';

    build-system = [
      pythonPkgs.setuptools
    ];

    dependencies = with pythonPkgs; [
      blake3
      charset-normalizer
      click
      cookiecutter
      gitpython
      httpx
      imageio-ffmpeg
      mixpanel
      packaging
      pathspec
      posthog
      psutil
      pyyaml
      questionary
      requests
      rich
      ruff
      semver
      tomlkit
      typer
      typing-extensions
      uv
      websocket-client
    ];

    optional-dependencies = with pythonPkgs; {
      dev = [
        pre-commit
        pytest
        pytest-cov
        ruff
      ];
    };

    pythonImportsCheck = [
      "comfy_cli"
    ];

    # blake3 is a declared dependency nothing in the tree imports, so the
    # >=1.0.9 floor buys nothing over nixpkgs' 1.0.8.
    pythonRelaxDeps = ["blake3" "mixpanel" "semver"];

    postFixup = ''
      rm $out/bin/comfy-cli $out/bin/comfycli
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    meta = {
      description = "Command Line Interface for Managing ComfyUI";
      homepage = "https://github.com/Comfy-Org/comfy-cli";
      license = lib.licenses.gpl3Only;
      maintainers = with lib.maintainers; [typedrat];
      mainProgram = "comfy";
    };
  }

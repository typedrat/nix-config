{
  osConfig,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) modules;
  inherit (config.home) username;
  userCfg = osConfig.rat.users.${username} or {};
  cliCfg = userCfg.cli or {};
  impermanenceCfg = osConfig.rat.impermanence;
  inherit (impermanenceCfg) persistDir;

  # Single source of truth for the scripting Python's package set: this same
  # function builds the `python3.withPackages` closure below and renders
  # ~/.python-packages.md, so the two can never drift out of sync.
  #
  # build123d is a local package (packages/build123d.nix) exposed as a
  # top-level pkgs.* attribute rather than merged into python3Packages, so
  # `with pkgs;` supplies the fallback that `with ps;` doesn't shadow.
  pythonPackagesFor = ps:
    with pkgs;
    with ps; [
      beautifulsoup4
      bokeh
      build123d
      click
      fastapi
      gradio
      ipython
      lxml
      manifold3d
      mapbox-earcut
      matplotlib
      networkx
      numba
      numpy
      opencv-python
      pandas
      pdfplumber
      pint
      polars
      psycopg2
      pydantic
      pymupdf
      pynput
      pypdf
      pytest
      requests
      rtree
      safetensors
      scikit-image
      scikit-learn
      scipy
      seaborn
      shapely
      sortedcontainers
      soundfile
      sympy
      torch
      torchaudio
      torchvision
      tqdm
      trimesh
      typing-extensions
      typing-inspection
      yacv-server
    ];

  pythonPackageNames = map (p: p.pname or p.name) (pythonPackagesFor pkgs.python3.pkgs);
in {
  config = modules.mkIf (cliCfg.enable && cliCfg.development.enable) {
    home.persistence.${persistDir} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".config/ipython"
        ".cache/uv"
        ".local/share/uv"
      ];
    };

    home.file.".python-packages.md".text = ''
      # System Python packages

      Generated from `modules/home-manager/cli/python.nix` — do not edit by
      hand, it's overwritten on every `home-manager switch`.

      The system-wide `python3` on PATH (provided by `uv` plus a
      `python3.withPackages` environment) is general-purpose scripting
      Python, not a project virtualenv — treat these packages as already
      available; there is no need to `pip install`, create a venv, or ask
      before using them in one-off scripts.

      When a script needs a package not on this list, don't silently work
      around it or vendor an alternative. Say so, and either ask whether to
      add it to `python.nix` or fall back to `uv run --with <package>` for a
      one-off.

      ## Available packages

      ${lib.concatMapStringsSep "\n" (name: "- ${name}") pythonPackageNames}

      `torch` is CUDA-enabled.

      Plus the standard library and `uv` itself (for `uv run --with <package>`
      one-offs that don't warrant a permanent addition).
    '';

    home.packages = with pkgs; [
      uv

      # General-purpose scripting Python with common data science / geometry /
      # scripting packages. Not used for actual Python application development.
      (python3.withPackages pythonPackagesFor)
    ];
  };
}

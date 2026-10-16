{
  python3,
  lib,
  callPackage,
  writeShellScript,
  makeWrapper,
  nix-update-script,
}: let
  common = callPackage ./common.nix {};
  frontend = callPackage ./frontend.nix {};

  hishel_0_1 = python3.pkgs.hishel.overrideAttrs (old: rec {
    version = "0.1.5";
    src = old.src.override {
      tag = version;
      hash = "sha256-OyQR/ruowNk5z4ITRHcIJn1kc0xLZiofmxajf6hNR9k=";
    };
  });
in
  python3.pkgs.buildPythonPackage rec {
    pname = "spoolman";
    inherit (common) version src;

    pyproject = true;

    nativeBuildInputs = [
      makeWrapper
      python3.pkgs.setuptools
      python3.pkgs.pythonRelaxDepsHook
    ];

    pythonRelaxDeps = [
      "setuptools"
      "websockets"
    ];

    postPatch = ''
      substituteInPlace pyproject.toml --replace-fail psycopg2-binary psycopg2

      # Upstream dropped [build-system] in 0.23.x, which makes setuptools fail on
      # the flat layout with several top-level directories.
      cat >> pyproject.toml <<EOF

      [build-system]
      requires = ["setuptools"]
      build-backend = "setuptools.build_meta"

      [tool.setuptools.packages.find]
      include = ["spoolman*"]
      EOF
    '';

    propagatedBuildInputs = with python3.pkgs; [
      uvloop
      alembic
      aiomysql
      anysqlite
      asyncpg
      fastapi
      hishel_0_1
      httptools
      httpx
      influxdb-client
      aiosqlite
      platformdirs
      prometheus-client
      psycopg2
      pydantic
      scheduler
      setuptools
      sqlalchemy
      sqlalchemy-cockroachdb
      uvicorn
      websockets
    ];

    pythonImportsCheck = ["spoolman"];

    postInstall = let
      start_script = writeShellScript "start-spoolman" ''
        ${lib.getExe python3.pkgs.uvicorn} "$@" spoolman.main:app;
      '';
    in ''
      mkdir -p $out/runpath/client_v2/build $out/bin
      cp -r $src/* $out/runpath
      cp -r ${frontend}/* $out/runpath/client_v2/build

      makeWrapper ${start_script} $out/bin/spoolman \
      --chdir $out/runpath \
      --prefix PYTHONPATH : "$out/${python3.sitePackages}" \
      --prefix PYTHONPATH : "${python3.pkgs.makePythonPath propagatedBuildInputs}" \
      --prefix PATH : "${python3.pkgs.alembic}/bin"
    '';

    passthru.frontend = frontend;
    passthru.updateScript = nix-update-script {
      extraArgs = ["--flake" "--override-filename" "packages/spoolman/common.nix" "--subpackage" "frontend"];
    };

    meta =
      common.meta
      // {
        description = "Spoolman server";
      };
  }

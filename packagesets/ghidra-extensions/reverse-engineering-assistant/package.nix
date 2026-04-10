{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
  python3Packages,
}: let
  version = "7.2.1";

  src = fetchFromGitHub {
    owner = "cyberkaida";
    repo = "reverse-engineering-assistant";
    rev = "v${version}";
    hash = "sha256-zyySyQ59R0QW45RT9VT2sHdylSKWeLZQRgeI4VA0y9o=";
  };

  self = buildGhidraExtension {
    pname = "reverse-engineering-assistant";
    inherit version src;

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    passthru.skills = lib.pipe "${src}/ReVa/skills" [
      builtins.readDir
      (lib.filterAttrs (_: type: type == "directory"))
      (lib.mapAttrs (name: _: "${src}/ReVa/skills/${name}"))
    ];

    passthru.python-wrapper = python3Packages.buildPythonApplication {
      pname = "mcp-reva";
      inherit version src;
      pyproject = true;

      build-system = with python3Packages; [
        setuptools
        setuptools-scm
        wheel
      ];

      dependencies = with python3Packages; [
        pyghidra
        mcp
        httpx
        httpx-sse
      ];

      env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

      meta = {
        description = "Python CLI wrapper for ReVa (Ghidra MCP server)";
        homepage = "https://github.com/cyberkaida/reverse-engineering-assistant";
        license = lib.licenses.asl20;
        mainProgram = "mcp-reva";
      };
    };

    meta = {
      description = "Ghidra extension providing an MCP server for AI-powered reverse engineering";
      homepage = "https://github.com/cyberkaida/reverse-engineering-assistant";
      license = lib.licenses.asl20;
    };
  };
in
  self

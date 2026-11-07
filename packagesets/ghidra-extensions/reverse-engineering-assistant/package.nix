{
  lib,
  fetchFromGitHub,
  buildGhidraExtension,
  gradle,
  python3Packages,
}: let
  # 7.3.1 doesn't build against Ghidra 12.2; master has the port but no
  # release yet.
  release = "7.3.1";
  version = "${release}-unstable-2026-11-03";

  src = fetchFromGitHub {
    owner = "cyberkaida";
    repo = "reverse-engineering-assistant";
    rev = "4d2fc5b4c5f4ce00d95f0bd6bdf0c64b67e65fc2";
    hash = "sha256-rCLaC2VZyKpgFsAgY9gxWmHCMccyRsoRncynur4zvhs=";
  };

  self = buildGhidraExtension {
    pname = "reverse-engineering-assistant";
    inherit version src;

    outputs = ["out" "skills"];

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./deps.json;
    };

    postInstall = ''
      mkdir -p "$skills"
      cp -r "$src/ReVa/skills/"* "$skills"/
    '';

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

      env.SETUPTOOLS_SCM_PRETEND_VERSION = release;

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

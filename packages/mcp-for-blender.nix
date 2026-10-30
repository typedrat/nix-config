{
  lib,
  fetchFromGitHub,
  python3Packages,
  nix-update-script,
}: let
  # Upstream requires mcp<2, and nixpkgs now defaults to mcp 2.
  pythonPkgs = python3Packages.overrideScope (final: _prev: {mcp = final.mcp_1;});
in
  pythonPkgs.buildPythonApplication {
    pname = "mcp-for-blender";
    version = "0-unstable-2026-10-29";
    pyproject = true;

    # Upstream publishes no tags.
    src = fetchFromGitHub {
      owner = "ahujasid";
      repo = "blender-mcp";
      rev = "992233bb258975a05eec8b5691465c50c2831e34";
      hash = "sha256-N47DkwrodzRIgg0SEQ1G9ITw4JliorGNotY6hsGpmok=";
    };

    # telemetry.py imports blender_mcp.config, which upstream gitignores because
    # it carries the project's telemetry endpoint and key. Without it every tool
    # call fails on import, so supply a stub that leaves collection off.
    postPatch = ''
      cat > src/blender_mcp/config.py <<'PY'
      from types import SimpleNamespace

      telemetry_config = SimpleNamespace(
          enabled=False,
          max_prompt_length=0,
          timeout=0,
          supabase_url="",
          supabase_anon_key="",
          supabase_bucket="",
      )
      PY
    '';

    build-system = [pythonPkgs.setuptools];

    dependencies = with pythonPkgs; [
      mcp
      httpx
    ];

    # The addon is a single file that Blender loads straight from its addons
    # directory, so ship it where the home-manager module can link it.
    postInstall = ''
      install -Dm444 addon.py $out/share/mcp-for-blender/addon.py
    '';

    nativeCheckInputs = [pythonPkgs.pytestCheckHook];

    pythonImportsCheck = ["blender_mcp"];

    passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version=branch"];};

    meta = {
      description = "MCP server connecting AI clients to a running Blender via its addon";
      homepage = "https://github.com/ahujasid/blender-mcp";
      license = lib.licenses.mit;
      mainProgram = "mcp-for-blender";
      platforms = lib.platforms.linux;
    };
  }

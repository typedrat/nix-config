{
  lib,
  fetchFromGitHub,
  python3Packages,
  nix-update-script,
}:
python3Packages.buildPythonApplication {
  pname = "mcp-for-blender";
  version = "0-unstable-2026-10-24";
  pyproject = true;

  # Upstream publishes no tags.
  src = fetchFromGitHub {
    owner = "ahujasid";
    repo = "blender-mcp";
    rev = "febcd90ece59c3416d7c55fd3723cea46bcaa59d";
    hash = "sha256-8D3DWeGAcffqwi0VUIpkoTLMzhG39CWj9OeaeRlT9OA=";
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

  build-system = [python3Packages.setuptools];

  dependencies = with python3Packages; [
    mcp
    httpx
  ];

  # The addon is a single file that Blender loads straight from its addons
  # directory, so ship it where the home-manager module can link it.
  postInstall = ''
    install -Dm444 addon.py $out/share/mcp-for-blender/addon.py
  '';

  nativeCheckInputs = [python3Packages.pytestCheckHook];

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

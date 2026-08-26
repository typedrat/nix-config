{
  fetchFromGitHub,
  python3Packages,
}:
# ha-mcp keeps its skill library in a git submodule at
# src/ha_mcp/resources/skills-vendor. nixpkgs fetches the release tag without
# submodules, so that directory arrives empty and the server logs "Skills
# directory not found" and registers ha_get_skill_guide with zero skills.
# Refetch the same tag with submodules; pyproject.toml already lists
# resources/skills-vendor/**/* as package data, so the tree ships as-is.
let
  inherit (python3Packages) ha-mcp toPythonApplication;

  # Tied to the submodule commit this tag pins, so it only stays valid for the
  # version nixpkgs is on. Reprefetch after a nixpkgs bump changes `version`.
  version = "8.3.0";
in
  assert ha-mcp.version == version;
    toPythonApplication (
      ha-mcp.overrideAttrs {
        src = fetchFromGitHub {
          owner = "homeassistant-ai";
          repo = "ha-mcp";
          tag = "v${version}";
          fetchSubmodules = true;
          hash = "sha256-2lWLF3gYVBVot8bHKlPW+FfwyY/R68Ky5tiF0jPStCg=";
        };
      }
    )

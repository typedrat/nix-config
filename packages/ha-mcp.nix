{
  callPackage,
  fetchFromGitHub,
  path,
}:
# ha-mcp keeps its skill library in a git submodule at
# src/ha_mcp/resources/skills-vendor. nixpkgs fetches the release tag without
# submodules, so that directory arrives empty and the server logs "Skills
# directory not found" and registers ha_get_skill_guide with zero skills.
# Refetch the same tag with submodules; pyproject.toml already lists
# resources/skills-vendor/**/* as package data, so the tree ships as-is.
let
  # This package shadows pkgs.ha-mcp, so the nixpkgs expression is imported
  # from the source tree rather than looked up by name. Path concatenation, not
  # string interpolation: "${path}" would copy the whole nixpkgs tree into the
  # store a second time, and nix-update's evaluator can't import from that copy.
  upstream = callPackage (path + "/pkgs/by-name/ha/ha-mcp/package.nix") {};

  # Tied to the submodule commit this tag pins, so it only stays valid for the
  # version nixpkgs is on. Reprefetch after a nixpkgs bump changes `version`.
  version = "8.7.0";
in
  assert upstream.version == version;
    upstream.overrideAttrs (old: {
      # The version follows nixpkgs, so the inherited updateScript would only
      # ever trip the assert above.
      passthru = old.passthru // {updateScript = null;};
      src = fetchFromGitHub {
        owner = "homeassistant-ai";
        repo = "ha-mcp";
        tag = "v${version}";
        fetchSubmodules = true;
        hash = "sha256-UQ6mUpVYWnQCOav8zzjwArmeHfdeh1g5GNFKQHRrO9U=";
      };
    })

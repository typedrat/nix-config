#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"
# nix-update needs to run from the flake root
cd "$script_dir/../.."

get_version() {
  grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

get_overrides_rev() {
  sed -n '/promptOverrides = fetchFromGitHub/,/};/ s/.*rev = "\([0-9a-f]\{40\}\)".*/\1/p' "$pkg_file"
}

# --- tweakcc-fixed itself (version, src hash, pnpmDeps hash) ---
old_version=$(get_version)
nix run nixpkgs#nix-update -- --flake tweakcc-fixed >&2
new_version=$(get_version)

# --- prompt overrides, kept in lockstep with the tweakcc bump ---
old_rev=$(get_overrides_rev)
auth_args=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
new_rev=$(curl -sf "${auth_args[@]}" \
  "https://api.github.com/repos/skrabe/lobotomized-claude-code/commits/HEAD" |
  jq -r '.sha')

if [[ "$new_rev" != "$old_rev" ]]; then
  new_hash=$(nix run nixpkgs#nix-prefetch-github -- \
    skrabe lobotomized-claude-code --rev "$new_rev" | jq -r '.hash')
  sed -i "/promptOverrides = fetchFromGitHub/,/};/ {
    s|rev = \"[0-9a-f]\{40\}\"|rev = \"$new_rev\"|
    s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|
  }" "$pkg_file"
fi

# --- report ---
changes=()
if [[ "$new_version" != "$old_version" ]]; then
  changes+=("tweakcc-fixed: $old_version -> $new_version")
fi
if [[ "$new_rev" != "$old_rev" ]]; then
  changes+=("prompt-overrides: ${old_rev:0:7} -> ${new_rev:0:7}")
fi

if [[ ${#changes[@]} -eq 0 ]]; then
  echo "tweakcc-fixed and prompt overrides are up to date" >&2
  exit 0
fi

message=$(printf '%s; ' "${changes[@]}")
message=${message%; }
echo "$message" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

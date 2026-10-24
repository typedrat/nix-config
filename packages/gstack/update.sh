#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"
# nix-update needs to run from the flake root
cd "$script_dir/../.."

old_rev=$(sed -n 's/.*rev = "\([0-9a-f]\{40\}\)".*/\1/p' "$pkg_file" | head -1)
old_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

new_rev=$(git ls-remote https://github.com/garrytan/gstack.git refs/heads/main | cut -f1)
if [[ -z "$new_rev" ]]; then
  echo "could not resolve gstack main" >&2
  exit 1
fi
if [[ "$new_rev" == "$old_rev" ]]; then
  echo "gstack is up to date ($old_version)" >&2
  exit 0
fi

# Upstream publishes no tags; every commit to main bumps VERSION.
new_version=$(curl -sf "https://raw.githubusercontent.com/garrytan/gstack/$new_rev/VERSION" | head -1 | tr -d '[:space:]')
if [[ -z "$new_version" ]]; then
  echo "could not read VERSION at $new_rev" >&2
  exit 1
fi

sed -i \
  -e "s|rev = \"$old_rev\"|rev = \"$new_rev\"|" \
  -e "0,/version = \"$old_version\"/s||version = \"$new_version\"|" \
  "$pkg_file"

# Recomputes the source hash and the node_modules hash for the new rev.
nix run nixpkgs#nix-update -- --flake gstack --version skip --custom-dep node_modules >&2

message="gstack: $old_version -> $new_version"
echo "$message" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

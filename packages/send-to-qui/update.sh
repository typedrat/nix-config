#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"

# Each GitHub release carries the Mozilla-signed .xpi as send-to-qui-<version>.xpi.
latest_version=$(curl -s https://api.github.com/repos/typedrat/send-to-qui-firefox/releases/latest | jq -r '.tag_name | ltrimstr("v")')

current_version=$(grep 'version = ' "$pkg_file" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "send-to-qui is up to date at $current_version" >&2
  exit 0
fi

url="https://github.com/typedrat/send-to-qui-firefox/releases/download/v${latest_version}/send-to-qui-${latest_version}.xpi"
new_hash=$(nix store prefetch-file --json "$url" | jq -r .hash)

sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|sha256 = \"[^\"]*\"|sha256 = \"$new_hash\"|" "$pkg_file"

echo "send-to-qui: $current_version -> $latest_version" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "send-to-qui: $current_version -> $latest_version" > "$COMMIT_MESSAGE_FILE"
fi

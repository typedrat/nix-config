#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"

addon_id="%7B76ef94a4-e3d0-4c6f-961a-d38a429a332b%7D"
api_url="https://addons.mozilla.org/api/v5/addons/addon/${addon_id}/"

# Fetch addon info from Mozilla API
addon_info=$(curl -s "$api_url")

latest_version=$(echo "$addon_info" | jq -r '.current_version.version')
download_url=$(echo "$addon_info" | jq -r '.current_version.file.url')
file_id=$(echo "$download_url" | sed -E 's|.*/file/([0-9]+)/.*|\1|')

# Get current version
current_version=$(grep 'version = ' "$pkg_file" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "ttv-lol-pro is up to date at $current_version" >&2
  exit 0
fi

# Download and hash the new XPI
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT
curl -sL "$download_url" -o "$tmpfile"
new_hash=$(nix hash file "$tmpfile")

# Update the package file
sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|fileId = \"[^\"]*\"|fileId = \"$file_id\"|" "$pkg_file"
sed -i "s|sha256 = \"[^\"]*\"|sha256 = \"$new_hash\"|" "$pkg_file"

echo "ttv-lol-pro: $current_version -> $latest_version" >&2

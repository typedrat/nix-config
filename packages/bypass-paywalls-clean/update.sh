#!/usr/bin/env bash
set -euo pipefail

# Get the directory of this script (for finding package.nix)
script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"

# Clone upstream repository to temp directory
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT
git clone --depth 1 https://gitflic.ru/project/magnolia1234/bpc_uploads.git "$tmpdir" >&2

# Parse release-hashes.txt for latest version + hash
# Format is pairs of lines: "SHA256 hash of <filename>:\n<hex hash>"
read -r latest_version latest_sha256 < <(
  awk '/bypass_paywalls_clean-[0-9].*\.xpi:/ && !/custom/ {
    sub(/.*bypass_paywalls_clean-/, "")
    sub(/\.xpi:.*/, "")
    version = $0
    getline hash
    gsub(/[[:space:]]/, "", hash)
    print version, hash
  }' "$tmpdir/release-hashes.txt" | sort -V | tail -1
)
latest_sri=$(nix hash convert "sha256:$latest_sha256")

# Get current version
current_version=$(grep 'version = ' "$pkg_file" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "bypass-paywalls-clean is up to date at $current_version" >&2
  exit 0
fi

# Update the package file
sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|bypass_paywalls_clean-[^\"]*\.xpi|bypass_paywalls_clean-${latest_version}.xpi|" "$pkg_file"
sed -i "s|sha256 = \"[^\"]*\"|sha256 = \"$latest_sri\"|" "$pkg_file"

echo "bypass-paywalls-clean: $current_version -> $latest_version" >&2

# Write commit message if requested
if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "bypass-paywalls-clean: $current_version -> $latest_version" > "$COMMIT_MESSAGE_FILE"
fi

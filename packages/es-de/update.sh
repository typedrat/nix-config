set -euo pipefail

pkg_file="packages/es-de/package.nix"

# Releases publish their AppImage through the GitLab package registry, so the
# download URL is an opaque package_files id with no version in it. Both the
# version and the id have to come from the releases API.
release=$(
  curl -sf "https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases?per_page=1" |
    jq '.[0]'
)

latest_version=$(echo "$release" | jq -r '.tag_name' | sed 's/^v//')
appimage_url=$(
  echo "$release" |
    jq -r '.assets.links[] | select(.name == "ES-DE_x64.AppImage") | .url'
)

if [[ -z "$latest_version" || -z "$appimage_url" ]]; then
  echo "es-de: could not find an x64 AppImage in the latest release" >&2
  exit 1
fi

current_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "es-de is up to date at $current_version" >&2
  exit 0
fi

echo "es-de: $current_version -> $latest_version" >&2

new_hash=$(nix store prefetch-file --json "$appimage_url" | jq -r '.hash')

sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|url = \"https://gitlab.com/es-de/[^\"]*\"|url = \"$appimage_url\"|" "$pkg_file"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|" "$pkg_file"

echo "es-de: $current_version -> $latest_version" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "es-de: $current_version -> $latest_version" > "$COMMIT_MESSAGE_FILE"
fi

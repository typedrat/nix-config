set -euo pipefail

pkg_file="packages/longshot-launcher/package.nix"

latest_version=$(
  curl -sf "https://git.magicbean.dev/api/v1/repos/MagicBeanDev/LongshotLauncher/releases/latest" |
    jq -r '.tag_name' | sed 's/^v//'
)

if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
  echo "longshot-launcher: could not find the latest release" >&2
  exit 1
fi

current_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "longshot-launcher is up to date at $current_version" >&2
  exit 0
fi

url="https://git-cdn.magicbean.dev/MagicBeanDev/LongshotLauncher/releases/download/v$latest_version/LongshotLauncher-v$latest_version-x86_64.AppImage"
new_hash=$(nix store prefetch-file --json "$url" | jq -r '.hash')

sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|" "$pkg_file"

echo "longshot-launcher: $current_version -> $latest_version" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "longshot-launcher: $current_version -> $latest_version" > "$COMMIT_MESSAGE_FILE"
fi

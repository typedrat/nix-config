set -euo pipefail

pkg_file="packages/qui-bin/package.nix"

# The releases atom feed carries branch pushes alongside real releases, and one
# of them ("backup/1994-pre-rebase") outsorts every semver tag. Ask the API for
# the release proper instead.
latest_version=$(
  curl -sf -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/autobrr/qui/releases/latest" |
    jq -r '.tag_name' |
    sed 's/^v//'
)

current_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "qui-bin is up to date at $current_version" >&2
  exit 0
fi

echo "qui-bin: $current_version -> $latest_version" >&2

base="https://github.com/autobrr/qui/releases/download/v${latest_version}"

prefetch() {
  nix store prefetch-file --json "$1" | jq -r '.hash'
}

# Every platform is pinned separately, so all four have to move together.
hash_x86_64_linux=$(prefetch "$base/qui_${latest_version}_linux_x86_64.tar.gz")
hash_aarch64_linux=$(prefetch "$base/qui_${latest_version}_linux_arm64.tar.gz")
hash_armv7l_linux=$(prefetch "$base/qui_${latest_version}_linux_arm.tar.gz")
hash_aarch64_darwin=$(prefetch "$base/qui_${latest_version}_darwin_arm64.tar.gz")

awk -v ver="$latest_version" \
  -v h_x86="$hash_x86_64_linux" \
  -v h_arm64="$hash_aarch64_linux" \
  -v h_arm="$hash_armv7l_linux" \
  -v h_darwin="$hash_aarch64_darwin" '
  /^  version = / { sub(/"[^"]*"/, "\"" ver "\""); print; next }
  /x86_64-linux = fetchurl/  { plat = h_x86 }
  /aarch64-linux = fetchurl/ { plat = h_arm64 }
  /armv7l-linux = fetchurl/  { plat = h_arm }
  /aarch64-darwin = fetchurl/ { plat = h_darwin }
  /hash = "sha256-/ && plat != "" { sub(/"sha256-[^"]*"/, "\"" plat "\""); print; next }
  { print }
' "$pkg_file" > "$pkg_file.new"
mv "$pkg_file.new" "$pkg_file"

echo "qui-bin: $current_version -> $latest_version" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "qui-bin: $current_version -> $latest_version" > "$COMMIT_MESSAGE_FILE"
fi

set -euo pipefail

pkg_file="packages/chaptarr/package.nix"

# Get latest versioned tag from Docker Hub (exclude "latest", "develop", "beta")
latest_version=$(
  curl -s "https://hub.docker.com/v2/repositories/robertlordhood/chaptarr/tags/?page_size=25&ordering=last_updated" |
    jq -r '.results[].name' |
    grep -E '^[0-9]+\.[0-9]+' |
    sort -V |
    tail -1
)

current_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "chaptarr is up to date at $current_version" >&2
  exit 0
fi

echo "chaptarr: $current_version -> $latest_version" >&2

# The manifest index digest is what pullImage uses
new_index_digest=$(
  skopeo inspect --raw "docker://robertlordhood/chaptarr:$latest_version" |
    sha256sum | awk '{print "sha256:" $1}'
)

# Prefetch hashes for each architecture
amd64_hash=$(nix-prefetch-docker --image-name robertlordhood/chaptarr --image-tag "$latest_version" --arch amd64 --os linux 2>&1 | grep 'sha256-' | sed 's/.*\(sha256-[^"]*\).*/\1/')
arm64_hash=$(nix-prefetch-docker --image-name robertlordhood/chaptarr --image-tag "$latest_version" --arch arm64 --os linux 2>&1 | grep 'sha256-' | sed 's/.*\(sha256-[^"]*\).*/\1/')

# Update the package file
sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|imageDigest = \"sha256:[^\"]*\"|imageDigest = \"$new_index_digest\"|" "$pkg_file"
sed -i "s|amd64 = \"sha256-[^\"]*\"|amd64 = \"$amd64_hash\"|" "$pkg_file"
sed -i "s|arm64 = \"sha256-[^\"]*\"|arm64 = \"$arm64_hash\"|" "$pkg_file"

echo "chaptarr: $current_version -> $latest_version" >&2

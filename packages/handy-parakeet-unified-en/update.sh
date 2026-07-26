set -euo pipefail

pkg_file="packages/handy-parakeet-unified-en/package.nix"

repo="handy-computer/parakeet-unified-en-0.6b-gguf"
filename="parakeet-unified-en-0.6b-Q8_0.gguf"

# The repo carries no tags or releases, so the branch head is the version. Ask
# for blobs so the LFS sha256 comes back with it — that is the same hash Nix
# wants, which saves re-downloading 700 MB just to compute it.
metadata=$(curl -sf "https://huggingface.co/api/models/${repo}?blobs=true")

latest_rev=$(jq -r '.sha' <<<"$metadata")
latest_date=$(jq -r '.lastModified | split("T")[0]' <<<"$metadata")
sha256=$(jq -r --arg f "$filename" '.siblings[] | select(.rfilename == $f) | .lfs.sha256' <<<"$metadata")

if [[ -z "$latest_rev" || -z "$sha256" || "$sha256" == "null" ]]; then
  echo "handy-parakeet-unified-en: could not read $filename metadata from the Hub" >&2
  exit 1
fi

current_rev=$(sed -nE 's/^  rev = "([^"]+)".*/\1/p' "$pkg_file")

if [[ "$latest_rev" == "$current_rev" ]]; then
  echo "handy-parakeet-unified-en is up to date at $current_rev" >&2
  exit 0
fi

hash=$(nix hash convert --hash-algo sha256 --to sri "$sha256")

sed -i \
  -e "s|^  rev = \"[^\"]*\";|  rev = \"${latest_rev}\";|" \
  -e "s|^    version = \"[^\"]*\";|    version = \"0-unstable-${latest_date}\";|" \
  -e "s|^    hash = \"sha256-[^\"]*\";|    hash = \"${hash}\";|" \
  "$pkg_file"

message="handy-parakeet-unified-en: ${current_rev:0:7} -> ${latest_rev:0:7}"
echo "$message" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

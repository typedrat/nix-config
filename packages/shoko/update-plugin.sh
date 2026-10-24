#!/usr/bin/env bash
# Updates a Shoko plugin's source.json to its newest stable release built
# against the server's major version. Called from each plugin's update.sh
# with that plugin's source.json.
set -euo pipefail

source_file=$(readlink -f "$1")
script_dir="$(dirname "$(readlink -f "$0")")"

server_version=$(grep 'version = ' "$script_dir/package.nix" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
major=${server_version%%.*}

repo=$(jq -r '.repo' "$source_file")
old_version=$(jq -r '.version' "$source_file")

# Each plugin publishes a manifest of its releases, with a SHA-256 per archive.
release=$(curl -sf "https://raw.githubusercontent.com/ShokoAnime/$repo/metadata/manifest.json" |
  jq -c --arg major "$major." '
    [.releases[] | select(.channel == "Stable")
      | {version, archive: (.archives[] | select(.runtime == "any" and (.abstraction | startswith($major))))}][0]')

if [[ -z "$release" || "$release" == null ]]; then
  echo "$repo: no stable release for abstractions $major.x, keeping $old_version" >&2
  exit 0
fi

new_version=$(jq -r '.version' <<<"$release")
if [[ "$new_version" == "$old_version" ]]; then
  echo "$repo is up to date at $old_version" >&2
  exit 0
fi

archive_hash=$(nix hash convert --hash-algo sha256 --to sri "$(jq -r '.archive.checksum | sub("^sha256:"; "")' <<<"$release")")
updated=$(jq --argjson r "$release" --arg hash "$archive_hash" \
  '.version = $r.version | .url = $r.archive.url | .hash = $hash' "$source_file")

# The images come from the plugin's repository at the release tag.
for kind in $(jq -r '.images | keys[]' "$source_file"); do
  url="https://raw.githubusercontent.com/ShokoAnime/$repo/v$new_version/source/Assets/$kind.svg"
  hash=$(nix store prefetch-file --json "$url" | jq -r '.hash')
  updated=$(jq --arg kind "$kind" --arg url "$url" --arg hash "$hash" \
    '.images[$kind] = {url: $url, hash: $hash}' <<<"$updated")
done

echo "$updated" >"$source_file"

message="$(jq -r '.name' "$source_file") plugin: $old_version -> $new_version"
echo "$message" >&2
if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" >"$COMMIT_MESSAGE_FILE"
fi

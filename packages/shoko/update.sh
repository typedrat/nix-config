#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"
plugins_file="$script_dir/plugins.json"
# nix-update needs to run from the flake root
cd "$script_dir/../.."

get_version() {
  grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

changes=()

# --- the server ---
# Every daily build is tagged v<next release>-dev.<n>. nix-update's own
# version discovery skips prereleases, so pick the newest tag here.
latest=$(git ls-remote --tags --refs https://github.com/ShokoAnime/ShokoServer.git 'v*-dev.*' |
  sed -E 's|.*refs/tags/v||' | sort -V | tail -1)
old_version=$(get_version)

if [[ -n "$latest" && "$latest" != "$old_version" ]]; then
  nix run nixpkgs#nix-update -- --flake shoko --version "$latest" >&2

  # Each daily can move NuGet dependencies, so the lockfile is regenerated
  # against the new source rather than trusted from the last bump.
  "$(nix build --no-link --print-out-paths .#shoko.passthru.fetch-deps)" "$script_dir/deps.json" >&2

  changes+=("shoko: $old_version -> $latest")
fi

# --- the released plugins ---
# Each plugin publishes a manifest of its releases with a SHA-256 per archive.
# Take the newest stable release built against the server's major version.
current=$(get_version)
abstraction_major=${current%%.*}
new_plugins=$(jq -c '.[]' "$plugins_file" | while read -r plugin; do
  repo=$(jq -r '.repo' <<<"$plugin")
  release=$(curl -sf "https://raw.githubusercontent.com/ShokoAnime/$repo/metadata/manifest.json" |
    jq -c --arg major "$abstraction_major." '
      [.releases[] | select(.channel == "Stable")
        | {version, archive: (.archives[] | select(.runtime == "any" and (.abstraction | startswith($major))))}][0]')
  if [[ -z "$release" || "$release" == null ]]; then
    echo "$repo: no stable release for abstractions $abstraction_major.x, keeping the pinned one" >&2
    echo "$plugin"
    continue
  fi
  hash=$(nix hash convert --hash-algo sha256 --to sri "$(jq -r '.archive.checksum | sub("^sha256:"; "")' <<<"$release")")
  jq -c --argjson r "$release" --arg hash "$hash" '.version = $r.version | .url = $r.archive.url | .hash = $hash' <<<"$plugin"
done | jq -s '.')

while read -r line; do
  [[ -n "$line" ]] && changes+=("$line")
done < <(jq -rn --argjson old "$(cat "$plugins_file")" --argjson new "$new_plugins" '
  [$old, $new] | transpose[] | select(.[0].version != .[1].version)
  | "\(.[0].name): \(.[0].version) -> \(.[1].version)"')
jq '.' <<<"$new_plugins" >"$plugins_file"

# --- report ---
if [[ ${#changes[@]} -eq 0 ]]; then
  echo "shoko and its plugins are up to date" >&2
  exit 0
fi

message=$(printf '%s; ' "${changes[@]}")
message=${message%; }
echo "$message" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

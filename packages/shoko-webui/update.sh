#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"
# nix-update needs to run from the flake root
cd "$script_dir/../.."

get_version() {
  grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

# Every daily build is tagged v<next release>-dev.<n>. nix-update's own
# version discovery skips prereleases, so pick the newest tag here.
latest=$(git ls-remote --tags --refs https://github.com/ShokoAnime/Shoko-WebUI.git 'v*-dev.*' |
  sed -E 's|.*refs/tags/v||' | sort -V | tail -1)
old_version=$(get_version)

if [[ -z "$latest" || "$latest" == "$old_version" ]]; then
  echo "shoko-webui is up to date at $old_version" >&2
  exit 0
fi

# Updates the source hash and the pnpm dependency hash together.
nix run nixpkgs#nix-update -- --flake shoko-webui --version "$latest" >&2

message="shoko-webui: $old_version -> $latest"
echo "$message" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

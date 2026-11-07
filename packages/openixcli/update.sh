#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$(readlink -f "$0")")"
pkg_file="$script_dir/package.nix"

latest_version=$(curl -sf https://api.github.com/repos/YuzukiTsuru/OpenixCLI/releases/latest | jq -r '.tag_name | ltrimstr("v")')
current_version=$(grep -m1 'version = ' "$pkg_file" | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "openixcli is up to date at $current_version" >&2
  exit 0
fi

prefetch() {
  nix store prefetch-file --json --unpack "$1"
}

src=$(prefetch "https://github.com/YuzukiTsuru/OpenixCLI/archive/refs/tags/v${latest_version}.tar.gz")
src_path=$(jq -r .storePath <<<"$src")

libefex_rev=$(sed -nE '/^\[dependencies\.libefex\]/,/^$/s/^rev = "([^"]+)"/\1/p' "$src_path/Cargo.toml")
if [[ -z "$libefex_rev" ]]; then
  echo "openixcli: no libefex rev in the manifest of v$latest_version" >&2
  exit 1
fi

libefex=$(prefetch "https://github.com/YuzukiTsuru/libefex/archive/${libefex_rev}.tar.gz")
libefex_path=$(jq -r .storePath <<<"$libefex")

# The lockfile has to describe the manifest the build sees, where libefex is a
# path dependency, so this applies the same rewrite as postPatch.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
install -m 644 "$src_path/Cargo.toml" "$work/Cargo.toml"
mkdir "$work/src"
cp "$src_path/src/main.rs" "$work/src/main.rs"
sed -i \
  -e "s|^git = \"https://github.com/YuzukiTsuru/libefex\"|path = \"$libefex_path/rust/libefex\"|" \
  -e "/^rev = \"$libefex_rev\"/d" \
  "$work/Cargo.toml"
nix shell nixpkgs#cargo nixpkgs#rustc -c cargo generate-lockfile --manifest-path "$work/Cargo.toml"
cp "$work/Cargo.lock" "$script_dir/Cargo.lock"

sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|libefexRev = \"[^\"]*\"|libefexRev = \"$libefex_rev\"|" "$pkg_file"
sed -i "/repo = \"OpenixCLI\"/,/hash = /s|hash = \"[^\"]*\"|hash = \"$(jq -r .hash <<<"$src")\"|" "$pkg_file"
sed -i "/repo = \"libefex\"/,/hash = /s|hash = \"[^\"]*\"|hash = \"$(jq -r .hash <<<"$libefex")\"|" "$pkg_file"

echo "openixcli: $current_version -> $latest_version" >&2

if [[ -n "${COMMIT_MESSAGE_FILE:-}" ]]; then
  echo "openixcli: $current_version -> $latest_version" >"$COMMIT_MESSAGE_FILE"
fi

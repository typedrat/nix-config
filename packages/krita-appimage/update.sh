set -euo pipefail

pkg_file="packages/krita-appimage/package.nix"

# KDE publishes the Qt5 build under a parallel 5.x line on download.kde.org,
# separate from the Qt6 6.x releases and from the source tags on invent.kde.org
# (which nix-update would follow straight onto Qt6). Track the newest 5.x
# directory to stay on Qt5.
latest_version=$(
  curl -s "https://download.kde.org/stable/krita/" |
    grep -oE 'href="5\.[0-9.]+/"' |
    grep -oE '5\.[0-9.]+' |
    sort -uV |
    tail -1
)

current_version=$(grep 'version = ' "$pkg_file" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [[ "$latest_version" == "$current_version" ]]; then
  echo "krita-appimage is up to date at $current_version" >&2
  exit 0
fi

echo "krita-appimage: $current_version -> $latest_version" >&2

url="https://download.kde.org/stable/krita/${latest_version}/krita-${latest_version}-x86_64.AppImage"
new_hash=$(nix store prefetch-file --json "$url" | jq -r '.hash')

sed -i "s|version = \"[^\"]*\"|version = \"$latest_version\"|" "$pkg_file"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"$new_hash\"|" "$pkg_file"

echo "krita-appimage: $current_version -> $latest_version" >&2

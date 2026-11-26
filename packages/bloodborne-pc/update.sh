set -euo pipefail

pkg_file="packages/bloodborne-pc/package.nix"
repo=Supermedo/bloodborne_pc
pr=173

auth_args=()
if [[ -n ${GITHUB_TOKEN:-} ]]; then
  auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

api() {
  curl -sf "${auth_args[@]}" "https://api.github.com/repos/$repo$1"
}

# Path tracing is still in PR 173: follow its head until it merges, then the
# branch it merged into. A PR closed without merging needs a person to pick a
# source.
pr_info=$(api "/pulls/$pr")
if [[ $(jq -r '.merged' <<< "$pr_info") == true ]]; then
  branch=$(jq -r '.base.ref' <<< "$pr_info")
  sha=$(api "/commits/$branch" | jq -r '.sha')
  source="$branch (PR $pr merged)"
elif [[ $(jq -r '.state' <<< "$pr_info") == open ]]; then
  sha=$(jq -r '.head.sha' <<< "$pr_info")
  source="PR $pr"
else
  echo "bloodborne-pc: PR $pr was closed without merging; choose a new source" >&2
  exit 1
fi

if [[ -z $sha || $sha == null ]]; then
  echo "bloodborne-pc: could not resolve the $source head" >&2
  exit 1
fi

current=$(sed -n 's/^  rev = "\([0-9a-f]\{40\}\)";$/\1/p' "$pkg_file" | head -n1)

if [[ $sha == "$current" ]]; then
  echo "bloodborne-pc is up to date at $current ($source)" >&2
  exit 0
fi

prefetch=$(nix-prefetch-git --quiet --fetch-submodules --rev "$sha" "https://github.com/$repo.git")
hash=$(jq -r '.hash' <<< "$prefetch")
date=$(jq -r '.date' <<< "$prefetch" | cut -dT -f1)
src=$(jq -r '.path' <<< "$prefetch")

if [[ -z $hash || $hash == null || -z $date || ! -d $src ]]; then
  echo "bloodborne-pc: could not prefetch $sha" >&2
  exit 1
fi

sed -i "s|^  rev = \"[0-9a-f]*\";|  rev = \"$sha\";|" "$pkg_file"
sed -i "s|^    hash = \"sha256-[^\"]*\";|    hash = \"$hash\";|" "$pkg_file"
sed -i "s|^  version = \"unstable-[0-9-]*\";|  version = \"unstable-$date\";|" "$pkg_file"

message="bloodborne-pc: $current -> $sha ($source, $date)"

# The FSR 4 assets are a fixed-output derivation keyed on fsr4Commit; when the
# new source pins another Q2RTX commit, fetch them the way the build does and
# record the new commit and hash.
fsr4_script=$src/tools/fetch_fsr4_assets.sh
fsr4_new=$(sed -n 's/^commit=\([0-9a-f]\{40\}\)$/\1/p' "$fsr4_script")
fsr4_old=$(sed -n 's/^  fsr4Commit = "\([0-9a-f]\{40\}\)";$/\1/p' "$pkg_file")

if [[ -z $fsr4_new || -z $fsr4_old ]]; then
  echo "bloodborne-pc: could not read the FSR 4 asset commit" >&2
  exit 1
fi

if [[ $fsr4_new != "$fsr4_old" ]]; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/tools"
  cp "$fsr4_script" "$work/tools/"
  BB_FSR4_TIERS="1080 2160" "$BASH" "$work/tools/fetch_fsr4_assets.sh" >&2
  # The script also builds opt/ when spirv-cross is on PATH; the derivation
  # never has it there, so its output holds only the downloads.
  rm -rf "$work/fsr4_shaders/opt"
  fsr4_hash=$(nix hash path --algo sha256 "$work/fsr4_shaders")

  sed -i "s|^  fsr4Commit = \"[0-9a-f]*\";|  fsr4Commit = \"$fsr4_new\";|" "$pkg_file"
  sed -i "s|^    outputHash = \"sha256-[^\"]*\";|    outputHash = \"$fsr4_hash\";|" "$pkg_file"
  message+=$'\n\n'"FSR 4 assets: Q2RTX ${fsr4_old:0:7} -> ${fsr4_new:0:7}"
fi

echo "$message" >&2

if [[ -n ${COMMIT_MESSAGE_FILE:-} ]]; then
  echo "$message" > "$COMMIT_MESSAGE_FILE"
fi

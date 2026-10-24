#!/usr/bin/env bash
# update-packages.sh — Update every local package that defines
# passthru.updateScript, one commit per package that changed.
#
# Run from the repository root. A failed update is rolled back with
# `git checkout -- . && git clean -fd`, so start from a clean tree.
#
# When GITHUB_ENV is set (GitHub Actions), the list of updated packages is
# exported as UPDATED_PACKAGES for the PR body.
#
# UPDATE_ONLY and UPDATE_EXCLUDE take space-separated package names to
# restrict the run, so packages whose bumps need review can go to a PR of
# their own.

set -euo pipefail

author="github-actions[bot] <github-actions[bot]@users.noreply.github.com>"

# nix-update can't handle packages built via external flake inputs or with
# extra pinned sources beyond src, so these run their own update.sh directly.
custom_update_packages=(bypass-paywalls-clean send-to-qui shoko shoko-plugin-anilist shoko-plugin-offlineimporter shoko-plugin-tmdb shoko-plugin-webaom shoko-webui ttv-lol-pro tweakcc-fixed)

is_custom() {
  local pkg=$1 custom
  for custom in "${custom_update_packages[@]}"; do
    [[ $pkg == "$custom" ]] && return 0
  done
  return 1
}

run_custom_update() {
  local pkg=$1 commit_msg=$2 pkg_dir
  pkg_dir=$(find packages -maxdepth 2 -name update.sh -path "*/$pkg/*" -exec dirname {} \;)
  if [[ -z $pkg_dir || ! -x $pkg_dir/update.sh ]]; then
    echo "::error::No update.sh found for $pkg"
    return 1
  fi
  echo "Running custom update script for $pkg..."
  COMMIT_MESSAGE_FILE="$commit_msg" "$pkg_dir/update.sh"
}

# shellcheck disable=SC2016 # ${n} is Nix interpolation, not shell
mapfile -t packages < <(
  nix eval .#packages.x86_64-linux \
    --apply 'pkgs: builtins.filter (n: (pkgs.${n}.passthru.updateScript or null) != null) (builtins.attrNames pkgs)' \
    --json | jq -r '.[]'
)

# `nix-update --use-update-script` runs the script inside
# `mkShell { inputsFrom = [pkg]; }`, which builds every build input first. When
# the script is nix-update-script that shell is pure overhead, and for packages
# with uncached heavy inputs (build123d pulls in cadquery-ocp-novtk) it outlives
# a CI runner. Record those scripts' arguments so nix-update can be called
# directly instead.
nix_update_args=$(mktemp)
trap 'rm -f "$nix_update_args"' EXIT
# shellcheck disable=SC2016 # ${n} is Nix interpolation, not shell
nix eval .#packages.x86_64-linux --json --apply '
  pkgs: let
    scriptOf = n: let s = pkgs.${n}.passthru.updateScript or null; in if s == null then null else s.command or s;
    isNixUpdate = c: builtins.isList c && baseNameOf (toString (builtins.head c)) == "nix-update";
  in
    builtins.listToAttrs (map (n: {
      name = n;
      value = builtins.tail (map toString (scriptOf n));
    }) (builtins.filter (n: isNixUpdate (scriptOf n)) (builtins.attrNames pkgs)))
' >"$nix_update_args"

updated=()
failed=()

for pkg in "${packages[@]}"; do
  if [[ -n ${UPDATE_ONLY:-} && " $UPDATE_ONLY " != *" $pkg "* ]] ||
    [[ " ${UPDATE_EXCLUDE:-} " == *" $pkg "* ]]; then
    continue
  fi
  echo "Updating $pkg..."

  # Attribute paths can contain slashes (peon-ping-packs/bender);
  # those would be read as directories that don't exist.
  commit_msg=".commit-message-${pkg//\//-}"

  if is_custom "$pkg"; then
    update_cmd=(run_custom_update "$pkg" "$commit_msg")
  else
    if jq -e --arg p "$pkg" 'has($p)' "$nix_update_args" >/dev/null; then
      mapfile -t update_args < <(jq -r --arg p "$pkg" '.[$p][]' "$nix_update_args")
    else
      update_args=(--use-update-script)
    fi
    update_cmd=(nix run nixpkgs#nix-update -- --flake "$pkg" "${update_args[@]}" --write-commit-message "$commit_msg")
  fi

  if ! "${update_cmd[@]}"; then
    echo "::error::Failed to update $pkg"
    failed+=("$pkg")
    rm -f "$commit_msg"
    git checkout -- .
    git clean -fd
    continue
  fi

  if [[ -f $commit_msg ]]; then
    nix fmt
    message=$(<"$commit_msg")
    rm "$commit_msg"
    git add -A
    git commit --author="$author" -m "$message"
    updated+=("$pkg")
  fi
done

if [[ -n ${GITHUB_ENV:-} ]]; then
  {
    if ((${#updated[@]})); then
      echo "UPDATED_PACKAGES<<EOF"
      printf -- '- %s\n' "${updated[@]}"
      echo "EOF"
    else
      echo "UPDATED_PACKAGES=_No packages were updated._"
    fi
  } >>"$GITHUB_ENV"
fi

if ((${#failed[@]})); then
  echo
  echo "The following packages failed to update:"
  printf -- '- %s\n' "${failed[@]}"
  exit 1
fi

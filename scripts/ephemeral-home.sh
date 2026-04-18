#!/usr/bin/env bash
# ephemeral-home.sh — Find files in $HOME that will be lost on reboot.
#
# On an impermanent NixOS system, /home is rolled back on every boot.
# Persisted paths are bind-mounted from /persist into the live filesystem,
# and Nix store paths appear as symlinks into /nix.
#
# This script finds everything that is NOT one of those — i.e., real files
# sitting on the ephemeral filesystem that will disappear on next reboot.
#
# Strategy:
#   1. Use find with -xdev so we never descend into bind mounts (persisted dirs).
#   2. Prune symlinks pointing into /nix or /persist (nix-managed / persisted).
#   3. Report what remains grouped by top-level directory.

set -euo pipefail

home="${HOME:?HOME is not set}"

# Collect ephemeral files:
#   -xdev:  stay on the same filesystem, skipping bind mounts from /persist
#   -not -type d: skip directories themselves (we care about files/symlinks)
#   Then filter out symlinks whose target starts with /nix or /persist.
mapfile -t files < <(
  find "$home" -xdev -not -type d 2>/dev/null | while IFS= read -r path; do
    # Keep non-symlinks (real ephemeral files)
    if [[ ! -L "$path" ]]; then
      printf '%s\n' "$path"
      continue
    fi
    # For symlinks, check where they point
    target="$(readlink -f "$path" 2>/dev/null || true)"
    case "$target" in
      /nix/*|/persist/*) ;; # managed — skip
      *) printf '%s\n' "$path" ;; # ephemeral symlink
    esac
  done
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No ephemeral files found in $home."
  exit 0
fi

# Two-level grouping: top-level dir -> sub-dir -> count
# Also track files directly in a top-level dir (no further nesting)
declare -A top_counts       # top -> total file count
declare -A sub_counts       # top/sub -> file count
declare -A top_direct_files # top -> newline-separated list of filenames directly in top
root_files=()
total=0

for f in "${files[@]}"; do
  rel="${f#"$home"/}"
  if [[ "$rel" != */* ]]; then
    # File directly in $HOME
    root_files+=("$rel")
  else
    top="${rel%%/*}"
    rest="${rel#*/}"
    top_counts["$top"]=$(( ${top_counts["$top"]:-0} + 1 ))
    if [[ "$rest" == */* ]]; then
      # Has a subdirectory under top
      sub="${rest%%/*}"
      sub_counts["$top/$sub"]=$(( ${sub_counts["$top/$sub"]:-0} + 1 ))
    else
      # File directly in the top-level dir
      top_direct_files["$top"]+="$rest"$'\n'
    fi
  fi
  (( ++total ))
done

# Sort top-level groups by count descending
mapfile -t sorted_tops < <(
  for key in "${!top_counts[@]}"; do
    printf '%d\t%s\n' "${top_counts[$key]}" "$key"
  done | sort -rn | cut -f2
)

echo "Ephemeral files in $home (will be lost on reboot): $total"
echo

for top in "${sorted_tops[@]}"; do
  count="${top_counts[$top]}"
  echo "$top/ ($count files)"

  # Collect and sort subdirectories by count descending
  mapfile -t sorted_subs < <(
    for key in "${!sub_counts[@]}"; do
      if [[ "$key" == "$top/"* ]]; then
        sub="${key#"$top"/}"
        printf '%d\t%s\n' "${sub_counts[$key]}" "$sub"
      fi
    done | sort -rn | cut -f2
  )

  for sub in "${sorted_subs[@]}"; do
    printf '  %s/ (%d files)\n' "$sub" "${sub_counts["$top/$sub"]}"
  done

  # Show files directly in the top-level dir (not in a subdirectory)
  if [[ -n "${top_direct_files["$top"]+x}" ]]; then
    while IFS= read -r fname; do
      [[ -z "$fname" ]] && continue
      echo "  $fname"
    done <<< "${top_direct_files[$top]}"
  fi

  echo
done

# Show root-level files last
if [[ ${#root_files[@]} -gt 0 ]]; then
  echo "./ (${#root_files[@]} files)"
  for rf in "${root_files[@]}"; do
    echo "  $rf"
  done
  echo
fi

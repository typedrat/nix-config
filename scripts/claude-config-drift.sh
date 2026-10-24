#!/usr/bin/env bash
# claude-config-drift.sh — Compare live Claude Code configuration with what
# Nix recreates.
#
# ~/.claude is persisted, so a reboot doesn't reset it: home-manager re-links
# its files on top at activation, and anything else in there survives only
# because the directory is persisted. This reports three kinds of drift:
#
#   1. Files the home-manager generation links (settings.json, CLAUDE.md,
#      rules, hooks, gstack's skill links) that are missing, were replaced by
#      a real file, or still point at another generation.
#   2. Managed-settings drop-ins in /etc/claude-code that differ from the
#      system generation.
#   3. Configuration Nix doesn't declare at all: real files among Claude
#      Code's config paths, and MCP servers registered in ~/.claude.json.
#      State Claude Code owns (claude.ai's synced skills, per-project MCP
#      servers) is left out unless --all is given.
#
# Usage: claude-config-drift.sh [--all] [--hm GENERATION] [--system TOPLEVEL]
#
# Both default to what is active now; the home-manager generation comes from
# the system generation's activation unit. Pass a freshly built one to see
# what a switch would change, e.g.
#   --hm "$(nix build --print-out-paths --no-link \
#     .#nixosConfigurations.$(hostname).config.home-manager.users.$USER.home.activationPackage)"
#
# Exits 1 when anything drifted.

set -euo pipefail

hm=
system=/run/current-system
all=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --hm) hm=$2; shift 2 ;;
    --system) system=$2; shift 2 ;;
    --all) all=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

config_dir="${CLAUDE_CONFIG_DIR:-${HOME:?HOME is not set}/.claude}"
# home-manager's own gcroot isn't updated when it runs as a NixOS module; the
# system generation's activation unit names the generation it activates.
if [[ -z "$hm" ]]; then
  hm=$(grep -o '/nix/store/[^ ]*-home-manager-generation' \
    "$system/etc/systemd/system/home-manager-$USER.service" 2>/dev/null | head -1 || true)
fi
hm=$(readlink -f "$hm")
[[ -d "$hm/home-files" ]] || { echo "not a home-manager generation: $hm" >&2; exit 2; }

found=0
section() { printf '\n%s\n' "$1"; }
report() { found=$((found + 1)); printf '  %-10s %s\n' "$1" "$2"; }

# Paths below config_dir, relative to it, that the generation accounts for,
# and the directories containing them.
declare -A managed managed_parent

# compare LIVE EXPECTED LABEL: EXPECTED is what the generation would link.
compare() {
  local live=$1 expected=$2 label=$3 parent=$3
  managed["$label"]=1
  while [[ "$parent" == */* ]]; do
    parent=${parent%/*}
    managed_parent["$parent"]=1
  done
  if [[ ! -e "$live" && ! -L "$live" ]]; then
    report missing "$label"
  elif [[ ! -L "$live" ]]; then
    report replaced "$label (a real file; activation will refuse or overwrite it)"
    [[ -f "$live" && -f "$expected" ]] && diff -u --label "nix: $label" --label "live: $label" "$expected" "$live" | sed 's/^/      /' || true
  elif [[ "$(readlink -f "$live")" != "$(readlink -f "$expected")" ]]; then
    report changes "$label"
    if [[ -f "$live" && -f "$expected" ]]; then
      diff -u --label "live: $label" --label "nix: $label" "$live" "$expected" | sed 's/^/      /' || true
    fi
  fi
}

section "home-manager files ($hm)"
rel_root="${config_dir#"$HOME"/}"
if [[ -d "$hm/home-files/$rel_root" ]]; then
  while IFS= read -r -d '' entry; do
    rel=${entry#"$hm/home-files/$rel_root/"}
    compare "$config_dir/$rel" "$entry" "$rel"
  done < <(find "$hm/home-files/$rel_root" \( -type l -o -type f \) -print0 | sort -z)
fi

# gstack's skills are linked by an activation script rather than home.file;
# the generation records which package tree it links from.
hosts=$(grep -o '/nix/store/[^ "]*/share/gstack-hosts' "$hm/activate" 2>/dev/null | head -1 || true)
if [[ -n "$hosts" && -d "$hosts/claude/skills" ]]; then
  for entry in "$hosts"/claude/skills/*; do
    compare "$config_dir/skills/${entry##*/}" "$entry" "skills/${entry##*/}"
  done
fi
[[ $found -eq 0 ]] && echo "  in sync"

section "managed settings (/etc/claude-code vs $system)"
before=$found
live_d=/etc/claude-code/managed-settings.d
want_d="$system/etc/claude-code/managed-settings.d"
for f in "$want_d"/*.json; do
  [[ -e "$f" ]] || continue
  name=${f##*/}
  if [[ ! -f "$live_d/$name" ]]; then
    report missing "$name"
  elif ! cmp -s "$live_d/$name" "$f"; then
    report changes "$name"
    diff -u --label "live: $name" --label "nix: $name" <(jq -S . "$live_d/$name") <(jq -S . "$f") | sed 's/^/      /' || true
  fi
done
for f in "$live_d"/*.json; do
  [[ -e "$f" ]] || continue
  [[ -e "$want_d/${f##*/}" ]] || report extra "${f##*/} (not in the system generation)"
done
[[ $found -eq $before ]] && echo "  in sync"

section "not declared in Nix (kept only because $config_dir is persisted)"
before=$found
# Claude Code's configuration paths; everything else in the directory is
# application state (sessions, history, caches, plugin installs).
# Paths below config_dir that Claude Code itself maintains.
app_owned=(skills/synced)

undeclared() {
  local path=$1 rel=${1#"$config_dir"/} child owned
  [[ -n "${managed[$rel]:-}" ]] && return 0
  if [[ $all -eq 0 ]]; then
    for owned in "${app_owned[@]}"; do
      [[ "$rel" == "$owned" ]] && return 0
    done
  fi
  # A directory the generation links into is only partly ours; look inside.
  if [[ -n "${managed_parent[$rel]:-}" && -d "$path" && ! -L "$path" ]]; then
    for child in "$path"/* "$path"/.[!.]*; do
      if [[ -e "$child" || -L "$child" ]]; then undeclared "$child"; fi
    done
    return 0
  fi
  # A link into the store came from Nix but isn't in this generation.
  if [[ -L "$path" && "$(readlink -f "$path")" == /nix/store/* ]]; then
    report stale "$rel (links into the store, but not from this generation)"
  else
    report undeclared "$rel"
  fi
}
for path in "$config_dir"/CLAUDE.md "$config_dir"/settings.json "$config_dir"/keybindings.json \
  "$config_dir"/*.sh "$config_dir"/{rules,hooks,skills,agents,commands,output-styles,themes}/*; do
  if [[ -e "$path" || -L "$path" ]]; then undeclared "$path"; fi
done
if [[ -f "$HOME/.claude.json" ]]; then
  while IFS= read -r server; do
    report mcp "$server (user-scope server in ~/.claude.json)"
  done < <(jq -r '.mcpServers // {} | keys[]' "$HOME/.claude.json")
  if [[ $all -eq 1 ]]; then
    projects=$(jq '[.projects // {} | .[] | select((.mcpServers // {}) != {})] | length' "$HOME/.claude.json")
    [[ $projects -gt 0 ]] && report mcp "$projects project(s) with project-scope servers in ~/.claude.json"
  fi
fi
[[ $found -eq $before ]] && echo "  nothing"

[[ $found -eq 0 ]]

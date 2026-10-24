# Claude Code statusline. Mirrors the look of the user's Powerlevel10k prompt
# (~/.p10k.zsh: Pure-style theme, Snazzy palette, no icons/segment-separators,
# lean flat-text segments) and adds Claude-specific fields (model, context
# remaining, session cost).
#
# Colors below are copied as DATA from ~/.p10k.zsh's `local <name>=<hex>`
# lines. This script must never source ~/.zshrc or ~/.p10k.zsh directly:
# p10k's instant-prompt/gitstatusd pipes have previously crashed Claude
# Code's shell snapshots (see project memory:
# project_claude_code_p10k_crash.md).

input="$(cat)"

# --- Snazzy palette (from ~/.p10k.zsh) ---
c_reset=$'\033[0m'
c_grey=$'\033[38;5;242m'      # POWERLEVEL9K_VCS_FOREGROUND / TIME / CONTEXT
c_red=$'\033[38;2;255;92;87m' # prompt_char error
c_yellow=$'\033[38;2;243;249;157m'  # command_execution_time
c_blue=$'\033[38;2;87;199;255m'     # dir
c_magenta=$'\033[38;2;255;106;193m' # prompt_char ok
c_cyan=$'\033[38;2;154;237;254m'    # vcs ahead/behind arrows
c_white=$'\033[38;2;241;241;240m'   # branch name — p10k uses dim grey 242
                                     # here (intentionally, to hide staleness);
                                     # bumped to white for on-screen readability

dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')"
model="$(printf '%s' "$input" | jq -r '.model.display_name // empty')"
remaining="$(printf '%s' "$input" | jq -r '.context_window.remaining_percentage // empty')"
cost="$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // .cost.totalCostUsd // .total_cost_usd // empty')"

# --- dir segment: p10k DIR_FOREGROUND=blue, full path with ~ substitution
# (no POWERLEVEL9K_SHORTEN_* configured, so p10k shows the untruncated path) ---
dir_display="${dir/#$HOME/\~}"
dir_segment="${c_blue}${dir_display}${c_reset}"

# --- git segment: white branch/@commit (readability tweak from p10k's grey),
# yellow '*' dirty marker, cyan ⇣⇡ ahead/behind ---
git_segment=""
if [ -n "$dir" ] && git -C "$dir" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git -C "$dir" --no-optional-locks symbolic-ref --quiet --short HEAD 2>/dev/null)"
  if [ -z "$branch" ]; then
    branch="@$(git -C "$dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)"
  fi

  dirty=""
  if [ -n "$(git -C "$dir" --no-optional-locks status --porcelain --ignore-submodules 2>/dev/null)" ]; then
    dirty="*"
  fi

  arrows=""
  upstream="$(git -C "$dir" --no-optional-locks rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
  if [ -n "$upstream" ]; then
    counts="$(git -C "$dir" --no-optional-locks rev-list --left-right --count "$upstream...HEAD" 2>/dev/null)"
    behind="${counts%%[[:space:]]*}"
    ahead="${counts##*[[:space:]]}"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && arrows="${arrows}⇣"
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null && arrows="${arrows}⇡"
  fi

  git_segment=" ${c_white}${branch}${c_reset}"
  [ -n "$dirty" ] && git_segment="${git_segment}${c_yellow}${dirty}${c_reset}"
  [ -n "$arrows" ] && git_segment="${git_segment}${c_cyan}${arrows}${c_reset}"
fi

# --- Claude-centric fields (right side) ---
right=""

if [ -n "$model" ] && [ "$model" != "null" ]; then
  right="${c_magenta}${model}${c_reset}"
fi

if [ -n "$remaining" ] && [ "$remaining" != "null" ]; then
  remaining_int="${remaining%.*}"
  ctx_color="$c_cyan"
  if [ "${remaining_int:-0}" -lt 20 ] 2>/dev/null; then
    ctx_color="$c_red"
  elif [ "${remaining_int:-0}" -lt 50 ] 2>/dev/null; then
    ctx_color="$c_yellow"
  fi
  [ -n "$right" ] && right="${right} ${c_grey}·${c_reset} "
  right="${right}${ctx_color}${remaining_int}%${c_reset}"
fi

if [ -n "$cost" ] && [ "$cost" != "null" ]; then
  cost_fmt="$(printf '%.2f' "$cost" 2>/dev/null)"
  [ -z "$cost_fmt" ] && cost_fmt="$cost"
  [ -n "$right" ] && right="${right} ${c_grey}·${c_reset} "
  right="${right}${c_yellow}\$${cost_fmt}${c_reset}"
fi

printf '%s%s' "$dir_segment" "$git_segment"
[ -n "$right" ] && printf '  %s' "$right"
# Trailing prompt_char glyph (p10k: magenta ❯), purely decorative here.
printf ' %s❯%s\n' "$c_magenta" "$c_reset"

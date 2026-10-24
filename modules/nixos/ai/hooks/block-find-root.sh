# PreToolUse/Bash: refuse `find` invocations rooted at /.
#
# This workstation's / spans a large ZFS array, so a root-level scan runs for
# tens of minutes and produces nothing a scoped search wouldn't. Matches the
# path operands only (the tokens between find's leading -H/-L/-P/-D/-O flags
# and its first -expression), so `find /nix/store …` and `grep / …` pass.

payload=$(cat)
# Fast path: most Bash calls never mention find, and this runs on all of them.
case $payload in *find*) ;; *) exit 0 ;; esac

command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command" ] || exit 0

find_root_re='(^|[^[:alnum:]_.$/-])find[[:space:]]+(-[HLPDO][^[:space:]]*[[:space:]]+)*([^-[:space:]][^[:space:]]*[[:space:]]+)*["'"'"']?/["'"'"']?([[:space:]]|$)'

printf '%s' "$command" | grep -Eq "$find_root_re" || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Blocked: `find /` scans the whole filesystem. This is a workstation with a large ZFS array, not a minimal sandbox — a root-level find runs for tens of minutes. Scope the search to a directory you already know (repo root, a package dir, ~/Development), or narrow with ls first. For system paths, search the specific one (/etc, /nix/store, /usr/share) instead of /. Quoted occurrences match too, so if you were only writing text containing this string, use the Write tool instead of a shell heredoc."
  }
}'

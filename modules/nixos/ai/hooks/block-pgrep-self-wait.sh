# PreToolUse/Bash|Monitor: refuse `while`/`until` loops that wait on `pgrep -f`.
#
# The tool runs each command as `bash -c '<command>'`, so that shell's own
# command line contains the pgrep pattern. `pgrep -f` excludes itself but not
# its parent shell, so it always finds a match and the wait loop never ends.
# The `[x]yz` bracket trick defeats the self-match and is let through, though
# it still hangs if the unbracketed text appears elsewhere in the command.

payload=$(cat)
# Fast path: this runs on every Bash call and almost none mention pgrep.
case $payload in *pgrep*) ;; *) exit 0 ;; esac

command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$command" ] || exit 0

printf '%s' "$command" | grep -Eq '(^|[^[:alnum:]_])(while|until)([[:space:]]|$)' || exit 0

full_flag_re='(^|[[:space:]])(-[[:alpha:]]*f[[:alpha:]]*|--full)([[:space:]]|$)'
hit=
while IFS= read -r segment; do
  printf '%s' "$segment" | grep -Eq "$full_flag_re" || continue
  case $segment in *'['*) continue ;; esac
  hit=1
  break
done < <(printf '%s\n' "$command" | grep -oE '(^|[^[:alnum:]_.-])pgrep([[:space:]][^;&|)`]*)?')

[ -n "$hit" ] || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Blocked: waiting in a loop on `pgrep -f` never terminates here. The command runs inside `bash -c \"<your command>\"`, so that shell'\''s own command line contains the pattern and pgrep keeps matching it after the real process exits. Instead: wait on a PID (`while kill -0 \"$pid\" 2>/dev/null; do sleep 1; done`, or `tail --pid=\"$pid\" -f /dev/null`); match the process name rather than its command line (`pgrep -x name`, no -f); or keep -f but bracket one character so the pattern no longer matches its own text (`pgrep -f \"[m]y-server\"`), and make sure the unbracketed name appears nowhere else in the command. Any mention of pgrep -f alongside a while/until loop matches, so if pgrep only appears in text you are writing, use the Write tool instead of a shell heredoc."
  }
}'

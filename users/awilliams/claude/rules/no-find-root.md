# Never search from the filesystem root

This is a workstation backed by a large ZFS array, not a minimal sandbox or RL
container. A scan rooted at `/` walks millions of files and takes tens of
minutes — it is never the fast way to find something.

Do not run `find /` (with or without `-prune`, `-xdev`, or `-maxdepth`). The
same applies to `grep -r`, `rg`, `du`, and `ls -R` started from `/`.

Instead:

- Scope to a directory you already know: the repo root, a package dir,
  `~/Development`, `node_modules/<scope>`.
- For system paths, name the specific one — `/etc`, `/nix/store`,
  `/usr/share` — rather than `/`.
- If you don't know where something lives, narrow with `ls` on a few likely
  parents first, or ask.

A `PreToolUse` hook (`block-find-root`) enforces the `find /` half of this and
will deny the tool call. The rest is on you.

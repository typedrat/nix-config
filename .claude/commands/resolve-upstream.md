---
allowed-tools:
  - Bash(gh repo view *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh api *)
---

First, get the repository name with `gh repo view --json nameWithOwner --jq '.nameWithOwner'`.

Then find the open GitHub issue titled "Upstream Issue Tracker" in that repository using `gh`. Read its body and all comments.

The issue body contains two sections:

- **Resolved**: A checklist of upstream issues/PRs that have been resolved. Each unchecked item has a reference (e.g. `NixOS/nixpkgs#12345`), status, and file locations.
- **Awaiting Upstream**: A table of still-open upstream references.

The comments (marked with `<!-- track-issues:ref -->`) contain notifications about newly resolved refs with locations that may need cleanup.

Your task: for each **unchecked resolved item** in the issue body, go to each listed location in the codebase and determine what cleanup is needed. The reference was to an upstream issue or PR that is now resolved, so any workarounds, patches, version pins, or TODO comments related to it may no longer be necessary.

For each location:
1. Read the file at the referenced line
2. Understand the context — why was the upstream issue referenced?
3. Determine if the workaround/patch/pin can be removed or simplified now that the upstream issue is resolved
4. Make the appropriate changes

After resolving all locations for a ref, report what you changed and why. If a location doesn't need changes (e.g. it's just a comment tracking the issue), explain why you're leaving it.

$ARGUMENTS

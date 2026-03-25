---
allowed-tools:
  - Bash(gh repo view *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh api *)
  - Bash(nix *)
  - Bash(git diff *)
  - Read
  - Edit
  - Grep
  - Glob
  - Agent
---

First, get the repository name with `gh repo view --json nameWithOwner --jq '.nameWithOwner'`.

Then find the open GitHub issue titled "Upstream Issue Tracker" in that repository using `gh`. Read its body and all comments.

The issue body contains two sections:

- **Resolved**: A checklist of upstream issues/PRs that have been resolved. Each unchecked item has a reference (e.g. `NixOS/nixpkgs#12345`), status, and file locations.
- **Awaiting Upstream**: A table of still-open upstream references.

The comments (marked with `<!-- track-issues:ref -->`) contain notifications about newly resolved refs with locations that may need cleanup.

Your task: for each **unchecked resolved item** in the issue body, go to each listed location in the codebase and determine what cleanup is needed. The reference was to an upstream issue or PR that is now resolved, so any workarounds, patches, version pins, or TODO comments related to it may no longer be necessary.

For each resolved ref, first fetch the upstream issue/PR to understand what was fixed and how. Then for each location:

1. Read the file at the referenced line
2. Understand the context — why was the upstream issue referenced?
3. Determine if the workaround/patch/pin can be removed or simplified now that the upstream issue is resolved
4. Make the appropriate changes

Common cleanup patterns in this codebase:

- **Nixpkgs patches** (`flake.nix` `nixpkgs-patch-*` inputs): Remove both the comment and the input block. The patcher module auto-discovers these, so no other changes are needed. Run `nix flake lock` afterwards to update the lock file.
- **Home-manager patches** (`flake.nix` `home-manager-patch-*` inputs): Same as above.
- **Workaround code**: Remove the workaround and any associated comment referencing the upstream issue.
- **TODO comments**: Remove the TODO if the blocking issue is resolved and the desired action can now be taken. Actually take the action if straightforward.
- **Version pins**: Remove the pin if the upstream fix means it's no longer necessary.

After making changes, verify the flake still evaluates with `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` for any affected host.

After resolving all locations for a ref, report what you changed and why. If a location doesn't need changes (e.g. it's just an informational comment), explain why you're leaving it.

$ARGUMENTS

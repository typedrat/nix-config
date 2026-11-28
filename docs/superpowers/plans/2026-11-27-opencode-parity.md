# OpenCode V2 Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring OpenCode V2 up to parity with the Claude Code setup through a shared `rat.users.<name>.cli.ai` layer with per-harness overlays, machine-wide guards, and V2-native config.

**Architecture:** Shared `context`/`rules`/`skills` options under `cli.ai`, merged with `cli.ai.claude-code` and `cli.ai.opencode` overlays in each harness's Home Manager module. `/etc/opencode/plugins/rat-guards.ts` calls the same guard binaries as Claude Code's `10-guards` drop-in. `ai.nix` builds V2 `opencode.json` itself instead of using HM's V1 MCP integration.

**Tech Stack:** Nix (NixOS + Home Manager modules), OpenCode 2.3.0 V2 server plugin (TypeScript, Node built-ins only), sops.

**Spec:** `docs/superpowers/specs/2026-11-27-opencode-parity-design.md`

## Global Constraints

- OpenCode is 2.3.0; generated `opencode.json`/`cli.json` must pass `programs.opencode.validateFiles.{config,cli} = true`.
- No V1 keys (`plugin`, `permission`, `agent`, flat `mcp.<name>`) in generated or repo `opencode.json`.
- Claude Code outputs under `~/.claude/` and `/etc/claude-code/` stay functionally identical; the only allowed content diffs are `no-find-root.md` line 19 (`A PreToolUse hook` → `A tool hook`) and `hooks/peon-ping/peon.sh` now pointing at `bin/peon`.
- Guard plugin: Node built-ins only, default export `{ id: "rat.guards", setup }`, fails open on infrastructure errors, never throws out of `setup`.
- Every host must still evaluate: `ulysses`, `hyperion`, `iserlohn`.
- Don't touch the 13 unmanaged directories in `~/.config/opencode/skills/`.
- `flake.lock` changes are limited to `peon-ping` and `modern-web-guidance`.
- Comment density matches the surrounding code (sparse, explaining why).

## Review Focus

- A user with only the shared `cli.ai.context` set and no harness overlay: both harnesses link the same path unchanged. A user with both: content is joined shared-first with a blank line. (Task 1's eval checks.)
- A host where `peon-ping` or Chromium is disabled (`hyperion`, `iserlohn`): evaluation succeeds, no dangling plugin file, no `chrome-devtools` MCP. (Task 6, step 1.)
- A shell command containing `find`/`pgrep` that isn't a violation (`grep find README`, `pgrep -x foo`): the guard runs and allows it. (Task 2, step 2.)
- A guard binary that times out or prints non-JSON: the call goes through and an error is logged. (Task 2, step 2.)
- A user `cli.ai.opencode.settings.permissions` overlay: appended after the defaults, so its rules win. (Task 3, step 2.)

---

### Task 1: Shared AI options, layering, and user file move

**Files:**
- Modify: `modules/shared/users/cli/ai.nix` (add `context`/`rules`/`skills` at `cli.ai` and `cli.ai.opencode`; add `settings`/`cli` to `cli.ai.opencode`; keep `cli.ai.claude-code.*`)
- Create: `modules/home-manager/cli/ai-layering.nix`. This is a plain function file, not a module: `{lib}: { mergeContext, mergeHarness }`.
- Modify: `modules/home-manager/cli/development/claude-code.nix` (consume the merged values; base `force` entries on them; `peon.sh` → `${config.programs.peon-ping.package}/bin/peon`)
- Move: `users/awilliams/claude/CLAUDE.md` → `users/awilliams/ai/context.md`; `users/awilliams/claude/rules/*.md` → `users/awilliams/ai/rules/`
- Modify: `users/awilliams/ai/rules/no-find-root.md:19` (`A \`PreToolUse\` hook` → `A tool hook`)
- Modify: `users/awilliams.nix:36-42` (`cli.ai.context`, `cli.ai.rules`; `doc-artifact` stays under `cli.ai.claude-code.skills`)

**Interfaces:**
- Produces: `import ./ai-layering.nix {inherit lib;}` returns:
  - `mergeContext :: (lines|path) -> (lines|path) -> (lines|path)`. If one side is empty (`""`), return the other unchanged. Otherwise return `"${read shared}\n\n${read harness}"`, where `read` is `builtins.readFile` for paths.
  - `mergeHarness :: aiCfg -> harnessCfg -> { context; rules; skills; }`, with `rules = aiCfg.rules // harnessCfg.rules` and `skills = aiCfg.skills // harnessCfg.skills`.
- Produces options: `rat.users.<n>.cli.ai.{context,rules,skills}`, `rat.users.<n>.cli.ai.opencode.{context,rules,skills,settings,cli}`, all with the types and defaults from spec §1.

- [ ] **Step 1: Record baseline Claude Code outputs**

Run:
```bash
nix build --no-link --print-out-paths .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.home-files > /tmp/opencode/hm-before
```
Expected: one store path. Keep it for step 5.

- [ ] **Step 2: Add the options, helper, and wiring; move the user files**

Check the `mergeContext` behaviour with:
```bash
nix eval --impure --expr 'let lib = (import <nixpkgs> {}).lib; m = (import ./modules/home-manager/cli/ai-layering.nix {inherit lib;}).mergeContext; in [ (m "" ./users/awilliams/ai/context.md == ./users/awilliams/ai/context.md) (m "a" "b" == "a\n\nb") (m "a" "" == "a") ]'
```
Expected: `[ true true true ]`

- [ ] **Step 3: Evaluate the effective Claude Code values**

Run:
```bash
nix eval --json .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.programs.claude-code.rules --apply builtins.attrNames
```
Expected: `["context7","no-find-root"]`. Then run the same command on `.skills`, which must include `"doc-artifact"`.

- [ ] **Step 4: Build `home-files` again and diff it against the baseline**

Run:
```bash
diff -r "$(cat /tmp/opencode/hm-before)/.claude" "$(nix build --no-link --print-out-paths .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.home-files)/.claude"
```
Expected: differences only in `rules/no-find-root.md` (the line 19 wording) and `hooks/peon-ping/peon.sh` (the new target). `CLAUDE.md` content is byte-identical.

- [ ] **Step 5: Commit**

```bash
git add modules/shared/users/cli/ai.nix modules/home-manager/cli/ai-layering.nix modules/home-manager/cli/development/claude-code.nix users/awilliams.nix users/awilliams/ai users/awilliams/claude
git commit -m "ai: shared cli.ai context, rules and skills with per-harness overlays"
```

### Task 2: OpenCode machine-wide guards plugin

**Files:**
- Create: `modules/nixos/ai/plugins/rat-guards.ts` (placeholders `@blockFindRoot@`, `@blockPgrepSelfWait@`)
- Modify: `modules/nixos/ai/default.nix`. Hoist the two `mkGuard` derivations into `let`. Reuse them in `10-guards`. Add `environment.etc."opencode/plugins/rat-guards.ts"`: `source = pkgs.replaceVars ./plugins/rat-guards.ts {...}`, `mode = "0444"`, gated on `cfg.enable`.

**Interfaces:**
- Consumes: the guard stdin contract `{"tool_input":{"command": string}}`. On deny, a guard prints `{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason": string}}` and exits 0. On allow, it prints nothing.
- Produces: `export default { id: "rat.guards", async setup(ctx) }`. The plugin registers `ctx.tool.hook("execute.before", cb)`. `cb` acts only when `event.tool === "shell" && typeof event.input?.command === "string"`, and throws `new Error(reason)` on deny. `find` triggers `block-find-root` and `pgrep` triggers `block-pgrep-self-wait`. `execFile` gets `timeout: 5000`. If `ctx.tool.hook` is missing, it logs `[rat.guards] tool hook API unavailable; guards inactive`.

- [ ] **Step 1: Write the plugin and wire it in**

- [ ] **Step 2: Exercise the plugin against the built guards with a stub `ctx`**

Write `/tmp/opencode/guards-test.mjs`. It imports the built `etc/opencode/plugins/rat-guards.ts` with `node --experimental-strip-types`, captures the registered callback, and asserts:
- `{tool:"shell", input:{command:"find / -name x"}}` rejects with a message containing `Blocked: \`find /\``
- `{tool:"shell", input:{command:"while pgrep -f foo; do sleep 1; done"}}` rejects with a message containing `pgrep -f`
- `{tool:"shell", input:{command:"grep find README"}}` resolves
- `{tool:"shell", input:{command:"pgrep -x foo"}}` resolves
- `{tool:"read", input:{filePath:"/"}}` resolves
- With the guard path swapped for `/nonexistent`, `find / -x` resolves and `console.error` was called

Run:
```bash
etc=$(nix build --no-link --print-out-paths .#nixosConfigurations.ulysses.config.system.build.etc) && node --experimental-strip-types /tmp/opencode/guards-test.mjs "$etc/etc/opencode/plugins/rat-guards.ts"
```
Expected: all assertions pass and the script exits 0. (If the system `node` lacks `--experimental-strip-types`, use `nix shell nixpkgs#nodejs_24`.)

- [ ] **Step 3: Check that `/etc/claude-code/managed-settings.d/10-guards.json` is unchanged**

Run: `diff <(jq -S . /etc/claude-code/managed-settings.d/10-guards.json) <(jq -S . "$etc/etc/claude-code/managed-settings.d/10-guards.json")`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/ai
git commit -m "ai: enforce the shell guards in OpenCode through /etc/opencode/plugins"
```

### Task 3: OpenCode V2 configuration in `ai.nix`

**Files:**
- Modify: `flake.nix` (add `modern-web-guidance = { url = "github:GoogleChrome/modern-web-guidance"; flake = false; };` after `exa-mcp-server`, using the same comment style)
- Modify: `modules/home-manager/cli/ai.nix`
- Modify: `users/awilliams.nix` (`cli.ai.opencode.settings.permissions = [{action = "external_directory"; resource = "~/Development/vira/*"; effect = "allow";}];`)

**Interfaces:**
- Consumes: `mergeHarness` from Task 1, `cliCfg.ai.opencode.{settings,cli}`.
- Produces in `ai.nix`:
  - `toOpencodeMcp :: server -> attrs` for V2 `Mcp.{Remote,Local}ConfigEncoded`. A remote server gives `{type="remote"; url; headers?}`. A local server gives `{type="local"; command=[command]++args; environment?}`.
  - `mergeSettings :: base -> overlay -> attrs`. It concatenates `plugins`, `permissions`, `instructions` and `skills`, runs `lib.recursiveUpdate` over `mcp` and `agents`, and uses `//` for everything else.
- Settings values copied verbatim from spec §3: `plugins`, `agents`, the six `permissions` defaults (without the `vira` rule, which goes in the overlay), `mcp.servers` = transformed `mcpServers` + `exa`, `instructions` = `~/.config/opencode/rules/<name>.md` in sorted order, `skills = ["${inputs.modern-web-guidance}/skills"]`.
- `cli`: the existing keys, plus `theme.name = "catppuccin-${config.catppuccin.flavor}"` when `config.catppuccin.enable` (otherwise keep `"catppuccin-frappe"`), plus `attention = {notifications = true; sound = false;}`.
- `enableMcpIntegration = false`, `validateFiles = {config = true; cli = true;}`, `context = effective.context`, `skills = effective.skills`, and an `xdg.configFile."opencode/rules/<name>.md"` for each effective rule.

- [ ] **Step 1: Lock only the new input**

Run: `nix flake update modern-web-guidance`
Expected: only that node is added to `flake.lock` (check with `git diff --stat flake.lock`).

- [ ] **Step 2: Implement and evaluate the generated `opencode.json`**

Run:
```bash
hf=$(nix build --no-link --print-out-paths .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.home-files)
jq -e '(.plugin,.permission,.agent)==null and (.mcp|keys==["servers"]) and (.mcp.servers.exa.url=="https://mcp.exa.ai/mcp?client=agent-plugin") and (.mcp.servers|has("answeroverflow")|not) and (.permissions[0]=={"action":"external_directory","resource":"*","effect":"ask"}) and (.permissions[-1].resource=="~/Development/vira/*") and (.instructions==["~/.config/opencode/rules/context7.md","~/.config/opencode/rules/no-find-root.md"]) and (.skills[0]|endswith("/skills"))' "$hf/.config/opencode/opencode.json"
jq -e '.attention=={"notifications":true,"sound":false} and .theme.name=="catppuccin-frappe"' "$hf/.config/opencode/cli.json"
test -L "$hf/.config/opencode/AGENTS.md" -o -f "$hf/.config/opencode/AGENTS.md" && ls "$hf/.config/opencode/rules"
```
Expected: `true`, `true`, then `context7.md  no-find-root.md`. The build itself passing proves schema validation.

- [ ] **Step 3: Commit**

```bash
git add flake.nix flake.lock modules/home-manager/cli/ai.nix users/awilliams.nix
git commit -m "ai: native V2 OpenCode config with shared instructions, Exa and modern-web-guidance"
```

### Task 4: Remove answeroverflow

**Files:**
- Modify: `modules/home-manager/cli/ai.nix` (drop `answerOverflowKey = {};`, the `ANSWER_OVERFLOW_KEY` export, and any leftover `mcp.answeroverflow`)
- Modify: `secrets/awilliams/ai.yaml` (run `sops unset secrets/awilliams/ai.yaml '["answerOverflowKey"]'`)

- [ ] **Step 1: Remove the key on both sides and verify**

Run: `rg -n -i 'answer.?overflow' --hidden -g '!docs/**' . ; sops decrypt secrets/awilliams/ai.yaml | grep -c answerOverflowKey`
Expected: no `rg` matches, and the count is `0`.

- [ ] **Step 2: Commit**

```bash
git add modules/home-manager/cli/ai.nix secrets/awilliams/ai.yaml
git commit -m "ai: drop the AnswerOverflow MCP server and its key"
```

### Task 5: Unpin peon-ping

**Files:**
- Modify: `flake.nix:310-314` (`url = "github:PeonPing/peon-ping";`, remove the pin comment)
- Modify: `flake.lock` (via `nix flake update peon-ping`)

- [ ] **Step 1: Update and check that the adapter is the V2 one**

Run:
```bash
nix flake update peon-ping
hf=$(nix build --no-link --print-out-paths .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.home-files)
grep -q 'setup: async' "$(readlink -f "$hf/.config/opencode/plugins/peon-ping.ts")" && echo V2
```
Expected: `V2`. `git diff --stat flake.lock` shows only `peon-ping`.

- [ ] **Step 2: Commit**

```bash
git add flake.nix flake.lock
git commit -m "peon-ping: unpin for the OpenCode V2 adapter"
```

### Task 6: Repo `opencode.json`, docs, and whole-system verification

**Files:**
- Modify: `opencode.json` (replace with the V2 JSON from spec §5 verbatim)
- Modify: `CLAUDE.md` ("Coding Agent Configuration": shared `cli.ai` layer, `cli.ai.claude-code`/`cli.ai.opencode` overlays and how they merge, `/etc/opencode/plugins/rat-guards.ts`, and `ai-layering.nix`)

- [ ] **Step 1: Format, then evaluate all hosts**

Run:
```bash
nix fmt
for h in ulysses hyperion iserlohn; do nix eval --raw .#nixosConfigurations.$h.config.system.build.toplevel.drvPath >/dev/null && echo "$h ok"; done
nix build --no-link .#nixosConfigurations.ulysses.config.system.build.toplevel
```
Expected: `nix fmt` leaves no diff, all three hosts print `ok`, and the build succeeds.

- [ ] **Step 2: Commit**

```bash
git add opencode.json CLAUDE.md
git commit -m "ai: V2 repo opencode.json pointing at ha-mcp; document the shared agent layer"
```

- [ ] **Step 3: Switch and check live (needs the user's go-ahead; this modifies the running system)**

Run: `nix run .#switch`, then `opencode plugin list`, `opencode mcp list`, and `grep -E 'failed to load plugin|rat.guards' ~/.local/share/opencode/log/opencode.log | tail`
Expected:
- The plugin list includes `peon-ping`, `rat.guards`, `ex-machina.anthropic-auth` and `superpowers`.
- No new `failed to load plugin` lines.
- MCP shows `exa` and has no `answeroverflow`.
- In a fresh session, `find / -name x` is denied with the guard's reason, and `modern-web-guidance` is listed as a skill.
- `home-assistant` and `pangram` may show "needs authentication". Sign in to them through `/mcps`.

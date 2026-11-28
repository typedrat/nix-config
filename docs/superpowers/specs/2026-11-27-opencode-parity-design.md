# OpenCode V2 parity with Claude Code

Status: draft, pending review
Date: 2026-11-27

## Intent and why

Bring OpenCode V2 (v2.3.0) into parity with the existing Claude Code setup as
daily use shifts back toward OpenCode, while fixing broken and stale OpenCode
configuration (`answeroverflow`, V1 `peon-ping` adapter, V1 config keys, 404
`home-assistant` MCP).

Rather than mirroring Claude Code settings ad hoc in a second place, promote
agent-agnostic user instructions, rules, and skills into a shared
`rat.users.<name>.cli.ai` layer with per-harness layering on top, and drive
OpenCode's machine-wide shell guards from the exact same guard scripts Claude
Code already uses. Future additions stay in parity by construction.

## Goals

- Remove `answeroverflow` completely: OpenCode MCP entry, SOPS secret
  declaration, `ANSWER_OVERFLOW_KEY` shell export, and dead key in
  `secrets/awilliams/ai.yaml`.
- Introduce a shared `rat.users.<name>.cli.ai.{context,rules,skills}` layer
  consumed by both Claude Code and OpenCode, with per-harness layering under
  `cli.ai.claude-code` and `cli.ai.opencode`.
- Enforce the machine-wide shell guards (`block-find-root`,
  `block-pgrep-self-wait`) in OpenCode V2 via `/etc/opencode/plugins/` using
  the same guard binaries Claude Code uses.
- Fix `peon-ping` in OpenCode V2 by unpinning the `peon-ping` flake input so
  OpenCode receives upstream's V2 adapter, and enable native OpenCode desktop
  notifications (`attention.notifications = true`, `attention.sound = false`).
- Add Exa's remote MCP server and Google Chrome's `modern-web-guidance` skills
  (`github:GoogleChrome/modern-web-guidance`) declaratively to OpenCode.
- Migrate `modules/home-manager/cli/ai.nix` and repo `./opencode.json` to
  native OpenCode V2 schema, enable build-time JSON schema validation via Home
  Manager (`validateFiles.{config,cli}`), restore `external_directory`
  prompting, and fix `./opencode.json`'s `home-assistant` MCP to point at
  `ha-mcp`.
- Keep Claude Code's generated `~/.claude/` and `/etc/claude-code/` outputs
  functionally identical (no regressions).

## Non-goals

- Porting Claude Code's Cloudflare (5 MCPs) or PostHog (MCP + skills)
  marketplace plugins into OpenCode.
- Managing, modifying, or deleting the 13 existing unmanaged skill directories
  in `~/.config/opencode/skills/`.
- Replicating Claude-only capabilities that have no OpenCode V2 equivalent:
  `rust-analyzer-lsp` (OpenCode V2 removed LSP support),
  `tweakcc`/`lobotomized-claude-code` prompt patches, and the custom shell
  `statusLine` script.
- Removing `HOME_ASSISTANT_TOKEN` from `modules/home-manager/cli/ai.nix` or
  `secrets/awilliams/ai.yaml` (it may still be used by scripts outside
  `./opencode.json`).
- Switching `programs.opencode.mutableSettings` on; OpenCode's config files
  stay read-only from Nix, matching Claude Code.

## Anti-goals

- Duplicating guard regexes or shared instructions in two places that can
  drift.
- Mixing V1 `mcp.<name>` and V2 `mcp.servers.<name>` inside the generated
  `opencode.json`.
- Letting an unexpected error in the guard plugin (spawn failure, timeout, bad
  JSON) crash OpenCode's V2 plugin supervisor (a failing plugin can take down
  the entire V2 plugin generation, including model/provider plugins).
- Breaking evaluation on hosts where `peon-ping` or GUI/Chromium are disabled
  (`hyperion`, `iserlohn`).

## Constraints

- **OpenCode V2 plugin loading**: Server plugins under `/etc/opencode/plugins/`
  and `~/.config/opencode/plugins/` must default-export `{ id, setup }` (pure
  Node built-ins require no npm dependencies).
- **Home Manager MCP integration**: The locked Home Manager
  `programs.opencode.enableMcpIntegration` still writes V1 flat `mcp.<name>`
  rather than V2 `mcp.servers.<name>`. Producing pure V2 `mcp.servers`
  therefore requires setting `enableMcpIntegration = false` and transforming
  `mcpServers` directly in `modules/home-manager/cli/ai.nix`.
- **Home Manager JSON settings merging**: `programs.opencode.settings` uses
  `pkgs.formats.json {}`, whose `types.oneOf` value type does not merge
  colliding lists or nested attribute sets across module definitions. Layering
  user `cli.ai.opencode.settings` onto defaults in `ai.nix` must therefore
  merge lists and nested maps explicitly in Nix before passing the result to
  `programs.opencode.settings`.
- **V2 `external_directory` defaults and glob syntax**: OpenCode V2 allows
  `external_directory` by default (unlike V1 and Claude Code) and uses single
  `*` wildcards (which match across `/`) with canonical directory patterns
  ending in `/*`.
- **Claude Code compatibility overlap**: OpenCode auto-discovers
  `~/.claude/skills/` at lower precedence than `~/.config/opencode/skills/` and
  explicit `settings.skills` entries. Shared skills installed in both
  directories resolve by ID without duplicating entries in the model's skill
  list, and per-harness OpenCode overrides cleanly shadow shared or Claude-only
  skills of the same ID.
- **Documentation**: `CLAUDE.md` documents the coding agent configuration
  architecture and must be updated alongside the module changes.

## Approaches

### Considered alternatives

1. **Approach A — Shared `rat.users.<name>.cli.ai` layer + single-source guards (Selected)**
   - Promote agent-agnostic `context`, `rules`, and `skills` up to
     `rat.users.<name>.cli.ai`, while keeping per-harness `context`, `rules`,
     `skills`, and `settings` under both `cli.ai.claude-code` and
     `cli.ai.opencode` so each harness layers on top of the shared base.
   - Move shared user files (`CLAUDE.md` → `context.md`, `rules/`) from
     `users/awilliams/claude/` to `users/awilliams/ai/`, leaving Claude-only
     assets (`statusline.sh`, `skills/doc-artifact`) under `claude/`.
   - Emit `/etc/opencode/plugins/rat-guards.ts` from `modules/nixos/ai/default.nix`
     invoking the exact same `block-find-root` and `block-pgrep-self-wait`
     store binaries used by Claude Code.
   - *Trade-off*: Touches Claude Code's option wiring as well as OpenCode's,
     but keeps Claude Code's generated files functionally identical and makes
     cross-harness parity the default going forward.

2. **Approach B — OpenCode-only mirror (Rejected)**
   - Leave `modules/shared/users/cli/ai.nix`, `users/awilliams.nix`, and
     `claude-code.nix` unchanged, and have `modules/home-manager/cli/ai.nix`
     read directly from `cli.ai.claude-code.{context,rules}`.
   - *Trade-off*: Smaller diff, but couples OpenCode to options named
     `cli.ai.claude-code.*` and gives no clean way to layer OpenCode-only or
     Claude-only instructions/rules/skills independently.

3. **Approach C — Separate per-harness configs and native TypeScript guards (Rejected)**
   - Duplicate rules/context under `cli.ai.opencode` and port the bash guard
     regexes to TypeScript.
   - *Trade-off*: Eliminates subprocess invocation on guard hits, but splits
     rules and regexes across two implementations that will drift over time. A
     fast-path substring check (`find` / `pgrep`) in TypeScript already avoids
     spawning subprocesses on >99% of shell commands under Approach A.

### Why Approach A

The user explicitly selected Approach A with per-harness layering on top of the
shared base. It prevents drift between harnesses, supports genuine per-harness
divergences (such as Claude-only `doc-artifact` or future OpenCode-only rules),
and avoids duplicating guard logic.

## Design

### 1. Shared and per-harness user options

In `modules/shared/users/cli/ai.nix`, define a reusable set of option
definitions (`context`, `rules`, `skills`) at three levels under
`rat.users.<name>.cli.ai`:

- **Shared base (`rat.users.<name>.cli.ai`)**:
  - `context`: `types.either types.lines types.path`, default `""`
  - `rules`: `types.attrsOf (types.either types.lines types.path)`, default `{}`
  - `skills`: `types.attrsOf (types.oneOf [types.lines types.path types.str])`, default `{}`
- **Claude Code overlay (`rat.users.<name>.cli.ai.claude-code`)**:
  - `context`: `types.either types.lines types.path`, default `""`
  - `rules`: `types.attrsOf (types.either types.lines types.path)`, default `{}`
  - `skills`: `types.attrsOf (types.oneOf [types.lines types.path types.str])`, default `{}`
  - `settings`: `types.attrsOf types.anything`, default `{}` (unchanged)
- **OpenCode overlay (`rat.users.<name>.cli.ai.opencode`)**:
  - `context`: `types.either types.lines types.path`, default `""`
  - `rules`: `types.attrsOf (types.either types.lines types.path)`, default `{}`
  - `skills`: `types.attrsOf (types.oneOf [types.lines types.path types.str])`, default `{}`
  - `settings`: `types.attrsOf types.anything`, default `{}` (overlay merged onto `ai.nix` defaults for `opencode.json`)
  - `cli`: `types.attrsOf types.anything`, default `{}` (overlay merged onto `ai.nix` defaults for `cli.json`)

#### Layering semantics

Both `modules/home-manager/cli/development/claude-code.nix` and
`modules/home-manager/cli/ai.nix` compute effective per-harness values from
`aiCfg = cliCfg.ai` and the harness overlay (`claudeCfg` or `opencodeCfg`):

- **`context`**:
  - If only one side is non-empty (either a path or a non-empty string), pass
    it through untouched so single-source path symlinks are preserved.
  - If both shared and harness `context` are non-empty, normalize paths via
    `builtins.readFile` and join with `"\n\n"` (shared first, harness second).
- **`rules`**: `sharedRules // harnessRules` (harness adds new named rules or
  replaces a same-named shared rule).
- **`skills`**: `sharedSkills // harnessSkills` (harness adds new named skills
  or replaces a same-named shared skill).
- **Claude Code `home.file.*.force` entries**:
  `modules/home-manager/cli/development/claude-code.nix` must derive its
  `force = true` entries from the merged `effectiveContext`, `effectiveRules`,
  and `effectiveSkills` (not only `claudeCfg`), so Home Manager continues to
  replace pre-existing files under `~/.claude/`.
- **OpenCode `settings` and `cli` overlay merging**:
  - For `settings`, list-valued keys that `ai.nix` defines (`plugins`,
    `permissions`, `instructions`, `skills`) concatenate `base ++ overlay` so
    user entries append (matching OpenCode's last-rule-wins order for
    `permissions` and ordered loading for `plugins`/`instructions`/`skills`).
    Nested maps (`mcp.servers`, `agents`) merge via `lib.recursiveUpdate`.
    Other keys overlay with `//`.
  - For `cli`, merge with `lib.recursiveUpdate baseCli opencodeCfg.cli`.

#### User files layout (`users/awilliams/`)

- Move `users/awilliams/claude/CLAUDE.md` → `users/awilliams/ai/context.md`
  and assign to `cli.ai.context`.
- Move `users/awilliams/claude/rules/context7.md` and
  `users/awilliams/claude/rules/no-find-root.md` → `users/awilliams/ai/rules/`
  and assign to `cli.ai.rules`.
  - Update line 19 of `no-find-root.md` from `A PreToolUse hook (block-find-root)`
    to `A tool hook (block-find-root)` so it accurately describes both
    harnesses.
- Keep Claude-only assets under `users/awilliams/claude/`:
  - `users/awilliams/claude/statusline.sh`
  - `users/awilliams/claude/skills/doc-artifact/` assigned to
    `cli.ai.claude-code.skills.doc-artifact` (it depends on Claude's `Artifact`
    tool, which OpenCode does not have).

### 2. Machine-wide guards in OpenCode (`modules/nixos/ai/`)

In `modules/nixos/ai/default.nix`, hoist the `block-find-root` and
`block-pgrep-self-wait` `mkGuard` derivations into `let` bindings so both
Claude Code's `10-guards` managed drop-in and OpenCode's machine-wide plugin
reference the exact same store paths.

Add a self-contained V2 server plugin source (`modules/nixos/ai/plugins/rat-guards.ts`
or generated via `pkgs.replaceVars` / inline string with substituted store
paths) installed to `/etc/opencode/plugins/rat-guards.ts` via
`environment.etc` (mode `"0444"`, gated on `cfg.enable`):

- Uses only Node built-ins (`node:child_process`) — zero npm dependencies.
- Default-exports `{ id: "rat.guards", async setup(ctx) { ... } }`.
- In `setup(ctx)`:
  - Guards registration with a feature check (`typeof ctx?.tool?.hook === "function"`)
    and `try/catch` so unexpected host mismatches never fail plugin activation.
  - Registers `ctx.tool.hook("execute.before", async (event) => { ... })`.
- In the `execute.before` callback:
  - Returns immediately unless `event?.tool === "shell"` and
    `typeof event?.input?.command === "string"`.
  - Applies fast-path substring checks before spawning anything:
    - Run `block-find-root` only if `command.includes("find")`.
    - Run `block-pgrep-self-wait` only if `command.includes("pgrep")`.
  - Runs each matching guard binary asynchronously (`execFile`, `timeout: 5000`),
    writing `JSON.stringify({ tool_input: { command } })` to stdin and closing
    stdin.
  - Parses stdout JSON; if `parsed?.hookSpecificOutput?.permissionDecision === "deny"`,
    throws `new Error(reason)` with `permissionDecisionReason` (OpenCode V2
    catches errors thrown from `tool.hook("execute.before")` and surfaces them
    to the model as tool errors).
  - Catches and logs any infrastructure error (spawn failure, timeout, non-zero
    exit, malformed JSON) to `console.error` and fails open, ensuring a broken
    guard cannot wedge shell execution.

### 3. OpenCode V2 user configuration (`modules/home-manager/cli/ai.nix`)

#### Instructions, rules, and skills

- `programs.opencode.context = effectiveContext;` — writes
  `$XDG_CONFIG_HOME/opencode/AGENTS.md`, guaranteeing global instructions load
  in OpenCode without relying on `CLAUDE.md` fallback.
- For each `(name, value)` in `effectiveRules`, materialize
  `$XDG_CONFIG_HOME/opencode/rules/${name}.md` via `xdg.configFile` (`source`
  for paths, `text` for inline strings), and populate `settings.instructions`
  with `"~/.config/opencode/rules/${name}.md"` in deterministic sorted key
  order.
- `programs.opencode.skills = effectiveSkills;` — writes any shared or
  OpenCode-specific named skills under `~/.config/opencode/skills/<name>`
  without touching existing unmanaged directories in `~/.config/opencode/skills/`.
- Add flake input `modern-web-guidance`:
  ```nix
  modern-web-guidance = {
    url = "github:GoogleChrome/modern-web-guidance";
    flake = false;
  };
  ```
  and include `"${inputs.modern-web-guidance}/skills"` in OpenCode's V2
  `settings.skills` array. This declaratively exposes `modern-web-guidance` and
  `chrome-extensions` (and any future skills upstream adds) with no collision
  against `~/.config/opencode/skills/`.

#### MCP servers (native V2 `mcp.servers`)

- Keep `programs.mcp = { enable = true; servers = mcpServers; };` and
  `programs.claude-code.mcpServers = removeAttrs mcpServers ["context7" "linear-server"];`
  unchanged so Claude Code and `~/.config/mcp/mcp.json` are unaffected.
- Set `programs.opencode.enableMcpIntegration = false;` so Home Manager does
  not emit deprecated V1 flat `mcp.<name>` keys.
- Convert `mcpServers` into native V2 `settings.mcp.servers` via a small helper
  in `ai.nix` matching `Mcp.RemoteConfigEncoded` (`type = "remote"`, `url`,
  optional `headers`) and `Mcp.LocalConfigEncoded` (`type = "local"`,
  `command = [s.command] ++ (s.args or [])`, optional `environment`).
- Add OpenCode-only `exa` under `settings.mcp.servers`:
  ```nix
  exa = {
    type = "remote";
    url = "https://mcp.exa.ai/mcp?client=agent-plugin";
    headers."x-exa-source" = "agent-plugin";
  };
  ```
  (Claude Code already receives this MCP via `programs.claude-code.plugins.exa`,
  and OpenCode already discovers Exa's skills from `~/.claude/skills/exa`.)
- Remove `answeroverflow` from `settings.mcp`, remove
  `rat.userSecrets.ai.answerOverflowKey`, and remove
  `export ANSWER_OVERFLOW_KEY=...` from `programs.zsh.initContent`.

#### V1 → V2 top-level settings migration

Migrate `programs.opencode.settings` in `modules/home-manager/cli/ai.nix` from
V1 to native V2 fields (validated against OpenCode 2.3.0's `config.json`
schema):

- `plugin` → `plugins`:
  ```nix
  plugins = [
    "@ex-machina/opencode-anthropic-auth@next"
    "superpowers@git+https://github.com/obra/superpowers.git"
  ];
  ```
- `agent` → `agents`:
  ```nix
  agents = {
    build.model = "anthropic/claude-opus-5-5";
    plan.model = "anthropic/claude-opus-5-5";
    explore.model = "anthropic/claude-haiku-5-5";
  };
  ```
- `permission` → `permissions` (ordered array, last match wins), restoring V1 /
  Claude-like external directory prompting and carrying over `trustedDirectories`
  (`/home/awilliams/Development/vira`):
  ```nix
  permissions = [
    {action = "external_directory"; resource = "*"; effect = "ask";}
    {action = "external_directory"; resource = "/nix/store/*"; effect = "allow";}
    {action = "external_directory"; resource = "/tmp/*"; effect = "allow";}
    {action = "external_directory"; resource = "~/.claude/skills/*"; effect = "allow";}
    {action = "external_directory"; resource = "~/.gstack/*"; effect = "allow";}
    {action = "external_directory"; resource = "~/Development/vira/*"; effect = "allow";}
  ];
  ```
  *(Call made: placed `~/Development/vira/*` in `awilliams`'s `cli.ai.opencode.settings.permissions` overlay rather than hardcoding it for all users in `ai.nix`, mirroring how `trustedDirectories` lives in `users/awilliams.nix`.)*

#### CLI config (`programs.opencode.cli`) and validation

- Theme: use `"catppuccin-${config.catppuccin.flavor}"` when
  `config.catppuccin.enable` (preserving `"catppuccin-frappe"` on `ulysses`,
  matching `claude-code.nix`'s dynamic flavor lookup).
- Alerts: add `attention = { notifications = true; sound = false; };` so
  OpenCode posts desktop notifications while `peon-ping` handles sound packs
  without double audio.
- Enable build-time JSON schema validation:
  ```nix
  validateFiles = {
    config = true;
    cli = true;
  };
  ```

### 4. `peon-ping` unpin (`flake.nix`, `flake.lock`)

- Unpin `inputs.peon-ping.url` from
  `github:PeonPing/peon-ping/7a16f0b1da9dc73b5ada2393ba36482a89b42913` back to
  `github:PeonPing/peon-ping` and remove the stale comment about duplicate
  `home.file` keys (upstream fixed this with `lib.mkMerge` and added an
  OpenCode V2 adapter).
- Update `flake.lock` strictly for `peon-ping` and the new `modern-web-guidance`
  input (`nix flake update peon-ping modern-web-guidance`) so unrelated inputs
  do not churn.
- Keep `home.file.".config/opencode/plugins/peon-ping.ts"` in `ai.nix` pointing
  at `${config.programs.peon-ping.package}/share/peon-ping/adapters/opencode/peon-ping.ts`,
  which now exports `{ id: "peon-ping", server, setup }`.

### 5. Secrets, repo `./opencode.json`, and `CLAUDE.md`

- Remove `answerOverflowKey` from `secrets/awilliams/ai.yaml` via `sops`
  (matching commit `7ad4671`).
- Migrate `./opencode.json` in this repo to native V2 schema and update
  `home-assistant` to `ha-mcp`:
  ```json
  {
    "$schema": "https://opencode.ai/config.json",
    "mcp": {
      "servers": {
        "nixos": {
          "type": "local",
          "command": ["uvx", "mcp-nixos"]
        },
        "home-assistant": {
          "type": "remote",
          "url": "https://ha-mcp.thisratis.gay/mcp"
        }
      }
    },
    "permissions": [
      { "action": "external_directory", "resource": "~/Development/nixpkgs/*", "effect": "allow" },
      { "action": "external_directory", "resource": "~/Development/home-manager/*", "effect": "allow" },
      { "action": "external_directory", "resource": "/nix/store/*", "effect": "allow" }
    ]
  }
  ```
- Update the "Coding Agent Configuration" section in `CLAUDE.md` to document the
  shared `rat.users.<name>.cli.ai` options, per-harness overlays
  (`cli.ai.claude-code` and `cli.ai.opencode`), and `/etc/opencode/plugins/`
  machine-wide guards.

## Resolved during review

- **Guard hook API** (checked against the 2.3.0 bundle): `execute.before`
  receives `{ tool, sessionID, agent, messageID, id, input }`; the shell tool
  ID is `shell` (a built-in repair hook maps `bash` to it); a throw inside the
  callback is converted to a tool error. When `ctx.tool.hook` is missing, the
  plugin logs `[rat.guards] tool hook API unavailable; guards inactive` with
  `console.error` instead of skipping silently.
- **`/etc/opencode/plugins/`**: config discovery treats the system directory
  like the global one, and plugin discovery scans `plugin/` and `plugins/`
  under each config directory, so no `/etc/opencode/opencode.json` entry is
  needed.
- **`peon-ping` file ownership**: upstream's Home Manager module writes only
  `~/.openpeon/**`. It writes `~/.claude/hooks/**` and `~/.claude/skills/**`
  only when `claudeCodeIntegration` is on (default off), and it never writes
  `~/.config/opencode/plugins/`. The `ai.nix` and `claude-code.nix` entries
  stay. `claude-code.nix`'s `peon.sh` now points at `${package}/bin/peon` (the
  wrapper that has runtime `PATH`), as upstream's own integration does.
- **SOPS**: the admin key decrypts `secrets/awilliams/ai.yaml`, so the builder
  removes the key with `sops unset`, in the same commit that drops the Nix
  declaration.
- **`~` in permission resources**: documented as expanded for
  `external_directory`, `read` and `edit`. Kept as written; checked live.
- **Double loading of rules**: OpenCode's Claude compatibility reads
  `~/.claude/skills` and, only when no global `AGENTS.md` exists,
  `~/.claude/CLAUDE.md`. It does not read `~/.claude/rules`. The generated
  `AGENTS.md` therefore replaces the fallback, and each rule loads once.
  Checked live.

## What's left to the builder

- Exact helper structure and naming for `mergeContext`, `toOpencodeV2Mcp`, and
  overlay merging in `modules/home-manager/cli/ai.nix` and
  `modules/home-manager/cli/development/claude-code.nix` (or a small shared
  helper file if cleaner).
- Whether `rat-guards.ts` lives as a standalone file under
  `modules/nixos/ai/plugins/rat-guards.ts` substituted via `pkgs.replaceVars`
  or as a template in `modules/nixos/ai/default.nix`.
- Verifying upstream `peon-ping`'s `nix/hm-module.nix` evaluates cleanly on
  `ulysses` with no `home.file` collisions against `claude-code.nix` (and
  checking whether `claude-code.nix`'s `.claude/hooks/peon-ping/peon.sh` should
  keep pointing at `share/peon-ping/peon.sh` or `bin/peon`).
- Verifying OpenCode's schema validation, host builds, and live runtime
  behavior.

## Verification plan

1. **Formatting and schema validation**:
   - `nix fmt` produces no diffs.
   - `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel`
     succeeds (which exercises `programs.opencode.validateFiles.{config,cli}`
     against OpenCode 2.3.0's JSON schemas).
   - Evaluate `hyperion` and `iserlohn` to confirm no regressions on hosts
     without `peon-ping` or Chromium.
2. **Claude Code non-regression**:
   - Inspect built `~/.claude/{CLAUDE.md,rules/*,skills/*,settings.json}` and
     `/etc/claude-code/managed-settings.d/*` against current live files
     (`scripts/claude-config-drift.sh --hm ... --system ...`) — only the one-line
     wording tweak in `no-find-root.md` should differ.
3. **OpenCode generated config inspection**:
   - Verify generated `~/.config/opencode/opencode.json` contains native V2
     keys (`plugins`, `permissions`, `agents`, `mcp.servers`, `instructions`,
     `skills`), includes `exa`, omits `answeroverflow`, and has no V1 legacy
     keys.
   - Verify generated `~/.config/opencode/cli.json` contains
     `attention.notifications = true` and `attention.sound = false`.
   - Verify `~/.config/opencode/AGENTS.md` and `~/.config/opencode/rules/{context7,no-find-root}.md`
     are generated.
   - Verify `/etc/opencode/plugins/rat-guards.ts` exists in the built system
     toplevel with valid store paths to `block-find-root` and
     `block-pgrep-self-wait`.
4. **Live runtime check (after switch)**:
   - `opencode plugin list` shows `peon-ping`, `rat.guards`,
     `ex-machina.anthropic-auth`, and `superpowers` all loaded with no errors in
     `~/.local/share/opencode/log/opencode.log`.
   - `opencode mcp list` shows `exa`, `context7`, `linear-server`,
     `chrome-devtools`, `nixos`, and `home-assistant` (with `home-assistant` /
     `pangram` awaiting `/mcps` OAuth sign-in if not yet authenticated), and no
     `answeroverflow`.
   - Confirm `modern-web-guidance` and `chrome-extensions` appear in available
     skills, global `AGENTS.md` and `rules/*.md` appear in session instructions,
     and attempting a blocked `find /` or `while pgrep -f ...` shell call is
     denied by `rat.guards` with the guard's reason message.

## Risks and edge cases

- **Upstream `peon-ping` HM module regressions**: Unpinning from `7a16f0b`
  pulls months of commits. If `hm-module.nix` introduces an unexpected
  collision or option mismatch against `modules/shared/users/cli/ai.nix`,
  pinning to a verified recent commit or patching the specific collision is an
  easy fallback.
- **OpenCode `/etc/opencode/plugins/` behavior**: OpenCode's docs state
  `/etc/opencode/` loads `plugins/` like `~/.config/opencode/`. Live testing
  must confirm OpenCode 2.3.0 discovers `/etc/opencode/plugins/rat-guards.ts`
  directly (rather than requiring a subdirectory or explicit `plugins` entry in
  `/etc/opencode/opencode.json`); if a directory or `opencode.json` entry is
  needed, `modules/nixos/ai/default.nix` owns `/etc/opencode/` and can emit it.
- **`tool.hook("execute.before")` payload shape**: Verify live that `shell`
  tool invocations pass `event.tool === "shell"` and `event.input.command` as
  expected in OpenCode 2.3.0, and that a thrown `Error` is surfaced cleanly as
  a denied tool call rather than aborting the session.
- **Interactive OAuth sign-in**: `home-assistant` (`ha-mcp.thisratis.gay/mcp`),
  `pangram`, and (optionally, for higher limits / Exa Agent) `exa` use OAuth
  and will require one-time sign-in via `/mcps` in the TUI after switching.

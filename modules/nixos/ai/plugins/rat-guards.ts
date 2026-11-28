// OpenCode server plugin: runs the same shell guards Claude Code runs as
// PreToolUse hooks. Each guard reads Claude's hook payload on stdin and
// prints a deny decision, or nothing to allow.
import { execFile } from "node:child_process"

const guards: { trigger: string; path: string }[] = [
  { trigger: "find", path: "@blockFindRoot@" },
  { trigger: "pgrep", path: "@blockPgrepSelfWait@" },
]

function runGuard(path: string, command: string): Promise<string | undefined> {
  return new Promise((resolve) => {
    const child = execFile(path, { timeout: 5000 }, (error, stdout) => {
      if (error) {
        console.error(`[rat.guards] ${path} failed, allowing the command:`, error.message)
        return resolve(undefined)
      }
      if (!stdout.trim()) return resolve(undefined)
      try {
        const output = JSON.parse(stdout).hookSpecificOutput
        resolve(output?.permissionDecision === "deny" ? String(output.permissionDecisionReason) : undefined)
      } catch (parseError) {
        console.error(`[rat.guards] ${path} printed invalid JSON, allowing the command:`, parseError)
        resolve(undefined)
      }
    })
    child.stdin?.on("error", () => {})
    child.stdin?.end(JSON.stringify({ tool_input: { command } }))
  })
}

export default {
  id: "rat.guards",
  async setup(ctx: any) {
    if (typeof ctx?.tool?.hook !== "function") {
      console.error("[rat.guards] tool hook API unavailable; guards inactive")
      return
    }
    try {
      await ctx.tool.hook("execute.before", async (event: any) => {
        const command = event?.input?.command
        if (event?.tool !== "shell" || typeof command !== "string") return
        for (const guard of guards) {
          // Most commands mention neither word; skip the subprocess for them.
          if (!command.includes(guard.trigger)) continue
          const reason = await runGuard(guard.path, command)
          if (reason) throw new Error(reason)
        }
      })
    } catch (error) {
      console.error("[rat.guards] could not register the tool hook; guards inactive:", error)
    }
  },
}

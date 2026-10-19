/**
 * agent-spin: signals opencode turn state to the tmux spinner daemon.
 *
 * The plugin host runs inside the shared OpenCode service, which is no pane's
 * child and whose environment carries no TMUX_PANE, so the plugin cannot name
 * its own pane. It signs per project directory instead, and the daemon resolves
 * pane -> directory through pane_current_path, trusting a sign only while a
 * single opencode pane holds that directory.
 *
 * The directory is the *session's*, not the host's: a shared host serving many
 * locations would otherwise sign every turn under whichever location it happens
 * to live in. Turn events carry the session but not its location, so the
 * directory is read from the session itself and remembered; a session never
 * moves.
 *
 * Turn semantics come from the execution lifecycle OpenCode broadcasts for
 * every session, root and subagent alike:
 * - `session.execution.started` opens a turn: that directory is busy.
 * - `session.execution.succeeded` / `.failed` / `.interrupted` close it.
 * Steps live inside an execution (`session.step.started`/`.ended`), so they are
 * deliberately ignored: a turn stays busy across every step and tool call and
 * goes idle only when the execution settles.
 *
 * One file per plugin instance, holding that instance's whole directory map.
 * OpenCode loads the plugin again on every run and does not retire the instance
 * it replaces, so several instances live at once, all subscribed to every event,
 * and one shared file per directory would let the instance that knows least
 * erase the one that knows most. The daemon instead calls a directory busy when
 * *any* live instance says so; an instance that loaded mid-turn knows only the
 * turns it saw start, and staying silent about the rest is exactly right, since
 * silence never cancels another instance's busy.
 *
 * Liveness: the map is rewritten every 30 s whatever it holds, so a fresh mtime
 * proves the instance is alive; the file names its agent, so a writer left over
 * from an older layout cannot slip past the daemon as ours. Past the daemon's
 * trust window the instance is gone (service restarted, pane from an older run)
 * and its file is simply dropped: that pane shows no spinner until a fresh
 * instance signs it.
 *
 * Nothing is written until the plugin has seen a turn start (`observed`). After
 * a restart mid-turn the host cannot know about the turn already in flight, and
 * a premature "idle" would cancel the busy another live instance may be holding,
 * so staying silent leaves that turn unsigned instead.
 *
 * Sessions the user drives count as busy, and so do subagent sessions: the
 * parent stays busy across them anyway (its execution does not settle while it
 * waits), so counting the child only ever agrees with the parent.
 */
import { Plugin } from "@opencode/plugin"
import { mkdir, rm, writeFile } from "node:fs/promises"
import path from "node:path"

const HEARTBEAT_MS = 30_000
const BUSY = "busy"
const IDLE = "idle"

// A turn opens on `started` and closes on any terminal execution event.
const OPENING = "session.execution.started"
const CLOSING = new Set([
  "session.execution.succeeded",
  "session.execution.failed",
  "session.execution.interrupted",
  "session.deleted",
  "session.destroyed",
])

interface SpinEvent {
  type: string
  data?: { sessionID?: string }
}

const trim = (dir: string): string => dir.replace(/\/+$/, "")

export default Plugin.define({
  id: "opencode.agent-spin",
  setup(ctx) {
    const root = process.env.XDG_RUNTIME_DIR
    if (!root) return
    const stateDir = path.join(root, "tmux-agents")
    const instance = `oc-${process.pid.toString(36)}-${Math.random().toString(36).slice(2, 8)}`
    const file = path.join(stateDir, instance)

    const busy = new Map<string, string>() // sessionID -> directory, turns in flight
    const dirs = new Set<string>() // directories we have spoken about
    const known = new Map<string, string>() // sessionID -> directory, resolved once
    let observed = false
    const abort = new AbortController()

    // The whole map goes out every time: the daemon reads instances, not files
    // per directory, and must be able to tell "idle here" from "silent here".
    const signal = async (): Promise<void> => {
      if (!observed) return
      const states: Record<string, string> = {}
      for (const dir of dirs) states[dir] = IDLE
      for (const dir of busy.values()) states[dir] = BUSY
      try {
        await mkdir(stateDir, { recursive: true })
        await writeFile(file, JSON.stringify({ agent: "oc", states, ts: Date.now() }))
      } catch {
        /* a spinner must never break the agent */
      }
    }

    const heartbeat = setInterval(() => void signal(), HEARTBEAT_MS)
    heartbeat.unref?.()

    const directory = async (sessionID: string): Promise<string> => {
      const cached = known.get(sessionID)
      if (cached !== undefined) return cached
      try {
        const info = await ctx.session.get({ sessionID })
        const dir = info?.location?.directory
        if (typeof dir === "string" && dir) {
          const trimmed = trim(dir)
          known.set(sessionID, trimmed)
          return trimmed
        }
      } catch {
        /* an unresolvable turn stays unsigned, so this pane shows no spinner */
      }
      return ""
    }

    const run = async (): Promise<void> => {
      for await (const event of ctx.event.subscribe({ signal: abort.signal }) as AsyncIterable<SpinEvent>) {
        if (abort.signal.aborted) break
        const sessionID = event.data?.sessionID
        if (typeof sessionID !== "string") continue
        if (event.type === OPENING) {
          const dir = await directory(sessionID)
          if (!dir) continue
          busy.set(sessionID, dir)
          dirs.add(dir)
          observed = true
          void signal()
        } else if (CLOSING.has(event.type)) {
          if (busy.delete(sessionID)) void signal()
        }
      }
    }
    const running = run().catch(() => {
      /* a dead pump leaves its turns unsigned */
    })

    return async () => {
      abort.abort()
      clearInterval(heartbeat)
      try {
        await running
      } catch {
        /* already handled */
      }
      await rm(file, { force: true }).catch(() => void 0)
    }
  },
})

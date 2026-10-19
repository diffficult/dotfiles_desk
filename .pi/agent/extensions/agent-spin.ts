// tmux spinner signal: tell the tmux daemon when this pi instance is mid-turn
// instead of making it re-parse session JSONL files. The daemon's inference
// path keeps working, so a missing $TMUX_PANE here is harmless.
//
// The file is one per instance and holds the directories this instance speaks
// for, the contract the opencode plugin also follows: the daemon maps pane ->
// directory through pane_current_path and treats a directory as busy while any
// live instance says so. The state is rewritten every 30s whatever it is: the
// fresh mtime is what proves to the daemon that this signal can be trusted and
// its own inference skipped. A headless gentle-pi child inherits TMUX_PANE and
// must never sign the parent's pane, so only an attached TUI writes.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const HEARTBEAT_MS = 30_000;
const pane = process.env.TMUX_PANE;
const dir = process.env.TMUX_SPIN_DIR ?? path.join(process.env.XDG_RUNTIME_DIR ?? tmpdir(), "tmux-agents");
const file = pane ? path.join(dir, `pi-${process.pid.toString(36)}`) : undefined;
const project = process.cwd().replace(/\/+$/, "");

export default function agentSpin(pi: ExtensionAPI) {
  if (!file || !process.stdout.isTTY) return;
  const target = file;

  // A run ends at `agent_settled`, not `agent_end`: retries, compaction and
  // queued follow-ups can continue after `agent_end`, and the spinner would
  // lie if it went idle there. Runs are counted so a settling run never clears
  // a pane another run is still using.
  let runs = 0;

  const write = async (): Promise<void> => {
    try {
      await mkdir(dir, { recursive: true });
      const state = runs > 0 ? "busy" : "idle";
      await writeFile(target, JSON.stringify({ agent: "pi", states: { [project]: state }, ts: Date.now() }));
    } catch { /* a spinner must never break the agent */ }
  };

  const heartbeat = setInterval(() => { void write(); }, HEARTBEAT_MS);
  heartbeat.unref?.();
  void write();

  pi.on("agent_start", () => { runs += 1; void write(); });
  pi.on("agent_settled", () => { runs = Math.max(0, runs - 1); void write(); });
  pi.on("session_shutdown", () => { clearInterval(heartbeat); });
}

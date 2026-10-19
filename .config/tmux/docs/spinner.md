# Agent tab spinners

The window-status entries show a braille spinner while an agent is working in
that window:

| agent | idle | busy |
|---|---|---|
| opencode | `ʘ >` | `ʘ > ⠙` |
| pi (dev agent, title `π - …`) | `π >` | `π ⠙` |
| omp (oh-my-pi, title `π <glyph> …`) | animates its own title | — |

omp needs nothing from tmux: it animates the pane title itself and the format
just shows it.

## The shape of it

Two halves, one contract.

**Agents sign their own turn state.** They are the only ones who know when a turn
starts and ends; guessing it from a database or a session file was the original
approach and it was both slow and wrong at the edges.

**`scripts/opencode_spin.sh` maps panes to directories and animates.** It reads
no database and parses no session files. It polls the panes, reads the sign
files, sets `@oc_busy` / `@pi_busy` per pane and `@oc_spin` / `@pi_spin` globally,
and redraws.

Wiring:

- `tmux.conf.local:31` starts the daemon (`setsid -f`), so it survives the
  config reload. It holds an `flock` on `$XDG_RUNTIME_DIR/tmux-opencode-spin.lock`
  and exits immediately if another copy owns it.
- `tmux.conf.local` window-status formats read `#{@oc_busy}`, `#{@oc_spin}`,
  `#{@pi_busy}`, `#{@pi_spin}`.

## The pieces

| piece | file | lines | role |
|---|---|---|---|
| daemon | `scripts/opencode_spin.sh` | 176 | maps panes to directories, reads the signs, drives `@oc_*` / `@pi_*` and the frame |
| opencode signer | `~/.config/opencode/plugins/agent-spin.ts` | 156 | turns `session.execution.*` into a sign file |
| pi signer | `~/.pi/agent/extensions/agent-spin.ts` | 48 | turns `agent_start` / `agent_settled` into a sign file |
| tag generator | `scripts/gen_window_tags.py` | 56 | prints the native window-index tag chain to paste into the formats |
| autosave timer | `scripts/continuum_timer.sh` | 24 | replaces the `#()` continuum used as its clock |
| config | `tmux.conf.local` | +7/−4 | formats read `@`-options; daemon and timer launched at line 31 |
| plugin patch | `plugins/tmux-continuum/continuum.tmux` | +8/−1 | commented-out autosave interpolation (nested git checkout, not tracked here) |
| docs | `docs/README.md`, `docs/spinner.md` | — | this |

Extension discovery: opencode loads every `.ts` in `~/.config/opencode/plugins/`
into its shared service; pi loads every `.ts` in `~/.pi/agent/extensions/` into
each TUI.

## The signal contract

`$XDG_RUNTIME_DIR/tmux-agents/<agent>-<instance>`:

```json
{"agent": "oc", "states": {"/home/rx/.config/tmux": "busy"}, "ts": 1792429328923}
```

- **One file per plugin instance, not per directory.** opencode re-loads its
  plugin on every run without retiring the instance it replaces. Several live
  instances then see every event, including instances that loaded mid-turn and
  know nothing. With a shared file, the instance that knows least erases the one
  that knows most; with per-instance files and an OR over live instances, silence
  never cancels a busy.
- **Rewritten every 30 s whatever the state.** A fresh mtime is the liveness
  proof; the daemon trusts no file older than `STALE_STATE` (90 s), deletes it and
  lets the pane show idle. A dead plugin therefore cannot pin a spinner on.
- **The file names its agent and holds a `states` map.** A writer left over from
  an older layout cannot be mistaken for a current one.
- Directories are absolute, and the daemon matches them against
  `pane_current_path`. Trailing slashes are stripped on both sides of the
  comparison.

Writers:

- `~/.config/opencode/plugins/agent-spin.ts`
- `~/.pi/agent/extensions/agent-spin.ts`

## Turn boundaries (the part that is easy to get wrong)

**opencode**

- `session.execution.started` opens a turn; `session.execution.succeeded`,
  `.failed` and `.interrupted` close it. Both cover root and subagent sessions
  and are emitted by the session executor.
- `session.step.started` / `.ended` are per *step*, i.e. many per turn. Driving
  the spinner from them makes it drop between steps.
- `session.idle` is **never emitted** as an event (it exists only as an RPC/DB
  marker). Waiting for it leaves the spinner on forever.
- `session.execution.*` events carry **no `location`**. The plugin host runs in
  the shared `opencode serve --service` process, which is no pane's child: it has
  no `TMUX_PANE` and `ctx.location.directory` is the *host's* directory, not the
  session's. The directory therefore comes from
  `ctx.session.get({sessionID})` → `session.location.directory`.
- `ctx.event.subscribe()` delivers the event object itself (`type`, `data`), not
  a wrapper.

**pi**

- `agent_start` opens a run; `agent_settled` is the final boundary.
- `agent_end` closes only one low-level run: retries, overflow recovery,
  compaction and queued work can continue after it, so it would report idle
  mid-turn.

## Internals

### opencode plugin

- `Plugin.define({ id: "opencode.agent-spin", setup(ctx) })`, returning a disposer.
- Instance id `oc-<pid base36>-<6 random>`; the file is
  `$XDG_RUNTIME_DIR/tmux-agents/<instance>`. Nothing else identifies the writer.
- State kept in memory: `busy` (sessionID → directory, turns in flight), `dirs`
  (directories the instance has spoken about — a finished turn must be written
  as `idle`, not dropped, or the other instances' `busy` would never be
  contradicted), `known` (sessionID → directory, resolved once: a session never
  moves).
- `observed` gate: nothing is written before the first turn start. A freshly
  loaded instance cannot know about the turn already in flight, and a premature
  `idle` would cancel the `busy` another live instance is holding.
- Pump: `ctx.event.subscribe({ signal })`; the handler reads `event.data.sessionID`,
  ignores everything that is not a turn boundary (one property read per event —
  the reasoning/text deltas fire continuously), resolves the directory on
  `session.execution.started` and rewrites the file only on boundaries.
- Heartbeat every 30 s rewrites the whole map unchanged: liveness.
- Disposer: aborts the subscription, clears the heartbeat, awaits the pump and
  unlinks the file, so a retired instance leaves no stale `busy` behind.

### pi extension

- Signs only with `process.stdout.isTTY` and `$TMUX_PANE` present: a headless
  gentle-pi child inherits `TMUX_PANE` and must never sign the parent's pane.
- File `pi-<pid base36>`; the project is `process.cwd()` with trailing slashes
  trimmed, so it matches `pane_current_path`.
- `runs` counter: `agent_start` +1, `agent_settled` −1, state busy while
  `runs > 0`. Counting keeps one settling run from clearing a pane another run
  still uses.
- Writes on transitions and every 30 s; `session_shutdown` clears the heartbeat.

### daemon

- `flock(LOCK, LOCK_EX | LOCK_NB)` on `$XDG_RUNTIME_DIR/tmux-opencode-spin.lock`;
  losing the race means another copy owns the status line, so it exits. That is
  what makes `source-file` (which re-runs the launch line) harmless.
- Cadence: `FRAMES_PER_POLL` (4) × `FRAME_INTERVAL` (0.12 s) ≈ one pane/sign
  poll every 0.5 s; when nothing is busy it sleeps `IDLE_INTERVAL` (1 s) and
  touches nothing.
- `all_panes()`: one `list-panes -a -F` with id, command, path, title. It
  returns `None` on failure and the loop exits after two consecutive failures
  (one hiccup must not kill the spinner).
- Classification: opencode is `pane_current_command` equal to `opencode` or
  starting with `opencode.`; pi is a title starting with `π - `. omp's title
  starts `π <glyph>`, so it is excluded by design — it animates its own title.
- `read_signals(kind)`: one `listdir`, one `stat` per candidate file (prune at
  90 s), parse, require `agent` and a `states` dict, OR-merge into
  `{directory: busy}`.
- `frame()`: **one** tmux client per frame carrying `set -g @oc_spin`,
  `set -g @pi_spin`, the per-pane `@oc_busy` / `@pi_busy` flags (set or `-u`),
  and `refresh-client -S`. Flags are rewritten every frame rather than compared
  against a cache: they ride in a client that is spawned anyway, and dropping the
  cache removes state that had to survive reloads.
- `clear()` runs once on the busy → idle edge: unsets both glyphs and every flag.

## Why the status line must stay fork-free

Every `#()` in a status option **executes a process on every redraw**. Measured
on this config: 15 forks per redraw (6 × `window_id_tag.sh`, `cut | sh` for
`#{username}`/`#{hostname}`/`#{root}`, `continuum_save.sh`) at ~1.9 ms each →
25 ms per redraw. Once the spinner redraws at ~8 fps that is **164% of one core
in the tmux server alone**.

So the rule for this config:

1. Nothing that renders may execute a process.
2. Dynamic data lives in `@options` updated by events or by a daemon, and the
   format only expands native variables.
3. The status refresh is a display, never a scheduler.

The four sites that used to break this rule:

| site | was | now |
|---|---|---|
| `tmux_conf_theme_window_status_format` / `…_current_format` | `#(window_id_tag.sh …)` per window | nested `#{?#{==:#{window_index},N},…}` chain, generated by `scripts/gen_window_tags.py` |
| `tmux_conf_theme_status_right` | `#{username}`, `#{hostname}`, `#{root}` (ssh-aware helpers, 2 forks each) | `#{user}`, `#{host_short}`, no root marker |
| `status-right` | `#(continuum_save.sh)` | `scripts/continuum_timer.sh` on a real interval |

Result, same 8 fps animation: **~7% of one core total** (0.35% daemon, rest
redraws) instead of 112%. RSS 15 MB, one thread.

Behaviour changes from those edits: inside a pane with an ssh session the user
and host now show the local client's (`#{user}` / `#{host_short}` are native),
and the `☢` root marker is gone; it had no native equivalent and cost two forks.

Regenerating the tags after changing `tmux_conf_window_id_style`:

```sh
scripts/gen_window_tags.py            # fsquare
scripts/gen_window_tags.py roman      # hsquare, digital, roman, super, sub
```

Paste the "active window" fragment into `…_current_format` and the "other
windows" one into `…_format`, replacing the existing chain.

## What this replaced

The first version made the daemon *infer* turn state, and it was the wrong end of
the problem:

- a SQLite query over `session_v2` / `session_message` (2.1 ms per call) to find
  each opencode session's last message type;
- tail reads of pi's session JSONL to decide whether a turn was open;
- a `/proc` walk to spot a running tool child;
- pane-title ↔ session-title matching to guess which session a pane belonged to,
  with a `FRESH_MS` window to call the guess stale.

All of it is gone: the daemon reads signs and nothing else, ~430 lines became
176, and the failure mode changed from "a wrong spinner" to "no spinner". A turn
that starts before the plugin is loaded, or whose plugin never loads at all,
stays unsigned until the next turn — the deliberate price of not guessing.

The first version also wrote one sign file *per directory* through a `claim()`
helper that crashed the daemon at startup (`NameError`) — the daemon had been
dead for a while. Per-instance files plus the OR merge removed both the crash and
the clobbering.

## Timers that must not come back

`plugin/tmux-continuum/continuum.tmux` is **locally patched**: the call that
injects `#(continuum_save.sh)` into `status-right` is commented out, because
that plugin uses the status refresh as its autosave clock. `scripts/continuum_timer.sh`
runs the same save script every `@continuum-save-interval` minutes from one
sleeping process. Updating the plugin through TPM restores the upstream file and
brings the fork back; re-apply the patch (it is four lines, marked in the file).

## Known gotchas

- **`$tmux_conf_*` expands in file order.** oh-my-tmux sources
  `tmux.conf.local` sequentially, so a variable referenced *above* its assignment
  expands to empty — silently producing `#[fg=]`. Only the palette entries near
  the top (`tmux_conf_theme_colour_1..6`) are safe to use from the window-status
  formats, which sit mid-file.
- **Plugin instances leak.** `opencode serve` re-loads the plugin on every run
  and does not retire the old instance. That is why the contract is per-instance;
  watch the file count if behaviour ever looks contradictory:
  `ls $XDG_RUNTIME_DIR/tmux-agents`.
- **A pane shared by two opencode instances of the same directory cannot be told
  apart** by a directory-scoped sign. Both panes light up during that project's
  turn; the alternative was hiding the spinner from the pane that is working.
- **`refresh-client -S` costs ~2.5 ms** (client fork) by itself, so the trigger
  is not free either; the tick is `FRAME_INTERVAL` (0.12 s) in the daemon.

## Operating it

```sh
# restart after editing the daemon (the config re-runs it, flock kills the extra)
pkill -f '^python3 /home/rx/.config/tmux/scripts/opencode_spin.sh$'
tmux source-file ~/.config/tmux/tmux.conf

# what the daemon sees
cat "$XDG_RUNTIME_DIR/tmux-agents/"oc-*
tmux show-options -p -t "$TMUX_PANE" @oc_busy
tmux show-options -g @oc_spin

# cost, while a turn is running
P=$(pgrep -f 'opencode_spin.sh$'); S=$(tmux display -p '#{pid}')
a=$(awk '{print $14+$15}' /proc/$P/stat); b=$(awk '{print $14+$15}' /proc/$S/stat)
sleep 20
awk -v a=$a -v b=$b -v c=$(awk '{print $14+$15}' /proc/$P/stat) \
    -v d=$(awk '{print $14+$15}' /proc/$S/stat) \
    'BEGIN{printf "daemon %.2f%%  server %.2f%%\n",(c-a)/20,(d-b)/20}'
```

A spinner that never stops means a fresh sign file says `busy` for a directory
that no longer has a working turn: check `oc-*` / `pi-*` contents and whether the
agent process is still alive. A spinner that never starts means no fresh sign:
check the plugin loaded (`grep agent-spin ~/.local/share/opencode/log/opencode.log`)
and that the pane's `pane_current_path` matches the signed directory exactly.

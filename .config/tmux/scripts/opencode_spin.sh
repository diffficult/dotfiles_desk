#!/usr/bin/env python3
"""Agent tab spinners: relay the agents' own turn state into the tmux status line.

Both agents sign their turn state to $XDG_RUNTIME_DIR/tmux-agents: one small JSON
file per *instance*, ``{agent, states: {directory: "busy"|"idle"}}``, rewritten
every 30 s (see ~/.config/opencode/plugins/agent-spin.ts and
~/.pi/agent/extensions/agent-spin.ts). One file per instance and not per
directory, because opencode re-loads its plugin without retiring the one it
replaces: several live instances see every event, and a shared file would let the
instance that knows least erase the one that knows most. A directory is busy when
any live instance says so.

This process only maps panes to directories and animates. It reads no database
and parses no session files: the agents already know their own turns.
"""

import fcntl
import json
import os
import subprocess
import time

LOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "tmux-opencode-spin.lock")
STATE_DIR = os.environ.get("TMUX_SPIN_DIR") or os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "tmux-agents"
)
STALE_STATE = 90  # an instance that stopped heartbeating this long ago is gone
FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
FRAME_INTERVAL = 0.12  # ~8 fps: one tmux client per frame carries glyph + flags
FRAMES_PER_POLL = 4  # panes and signals are rescanned every ~0.5 s
IDLE_INTERVAL = 1.0  # sleep when nothing is busy (one pane scan per second)


def tmux(*args):
    return subprocess.run(["tmux", *args], check=False, capture_output=True, text=True)


def all_panes():
    """Live panes as (id, command, directory, title), or None when tmux fails."""
    out = tmux(
        "list-panes",
        "-a",
        "-F",
        "#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}",
    )
    if out.returncode:
        return None
    panes = []
    for line in out.stdout.splitlines():
        pane_id, cmd, path, title = (line.split("\t", 3) + [""] * 3)[:4]
        panes.append((pane_id, cmd, path, title))
    return panes


def read_signals(kind):
    """{directory: busy} merged over the live instances of one agent.

    A file has to name its agent and hold a directory map: a writer left over
    from an older layout would otherwise be read as ours, and a stale "busy" from
    a dead instance would pin a spinner on. Files older than STALE_STATE are
    dropped as we go: that instance stopped heartbeating, so it is gone."""
    states = {}
    now = time.time()
    try:
        names = os.listdir(STATE_DIR)
    except OSError:
        return states
    for name in names:
        if not name.startswith(kind + "-"):
            continue
        path = os.path.join(STATE_DIR, name)
        try:
            if now - os.stat(path).st_mtime >= STALE_STATE:
                os.unlink(path)
                continue
            with open(path) as handle:
                body = json.load(handle)
        except (OSError, ValueError):
            continue
        signed = body.get("states")
        if body.get("agent") != kind or not isinstance(signed, dict):
            continue
        for directory, state in signed.items():
            states[directory] = states.get(directory, False) or state == "busy"
    return states


def pane_flags(option, panes, busy):
    """Args that raise the flag on busy panes and drop it on the rest."""
    args = []
    for pane_id in panes:
        args += ["set-option", "-p"] + ([] if pane_id in busy else ["-u"]) + ["-t", pane_id, option]
        args += ["1", ";"] if pane_id in busy else [";"]
    return args


def frame(glyph, oc, pi, oc_busy, pi_busy):
    """One tmux client per frame: glyph, per-pane flags, redraw."""
    tmux(
        "set", "-g", "@oc_spin", glyph, ";",
        "set", "-g", "@pi_spin", glyph, ";",
        *pane_flags("@oc_busy", oc, oc_busy),
        *pane_flags("@pi_busy", pi, pi_busy),
        "refresh-client", "-S",
    )


def clear(oc, pi):
    tmux(
        "set", "-gu", "@oc_spin", ";",
        "set", "-gu", "@pi_spin", ";",
        *pane_flags("@oc_busy", oc, set()),
        *pane_flags("@pi_busy", pi, set()),
        "refresh-client", "-S",
    )


def poll():
    """(opencode panes, pi panes, oc busy, pi busy) by directory, or None."""
    panes = all_panes()
    if panes is None:
        return None
    oc = {pane: path for pane, cmd, path, _title in panes if cmd == "opencode" or cmd.startswith("opencode.")}
    pi = {pane: path for pane, _cmd, path, title in panes if title.startswith("π - ")}
    oc_sign = read_signals("oc")
    pi_sign = read_signals("pi")
    # A sign names a directory, and an opencode plugin cannot name a pane (it
    # lives in the shared service, not under the pane). One opencode pane per
    # directory is therefore attributed exactly; when two share it, both show
    # that project's turn rather than hiding the spinner from the working one.
    return (
        oc,
        pi,
        {pane for pane, path in oc.items() if oc_sign.get(path)},
        {pane for pane, path in pi.items() if pi_sign.get(path)},
    )


def main():
    lock = open(LOCK, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return  # another daemon owns the status line

    index = 0
    was_busy = False
    failures = 0

    while True:
        state = poll()
        if state is None:  # tmux is gone: stop, but not on a single hiccup
            if failures:
                break
            failures += 1
            time.sleep(IDLE_INTERVAL)
            continue
        failures = 0
        oc, pi, oc_busy, pi_busy = state

        if not (oc_busy or pi_busy):
            if was_busy:
                clear(oc, pi)
                was_busy = False
            time.sleep(IDLE_INTERVAL)
            continue

        for _ in range(FRAMES_PER_POLL):
            frame(FRAMES[index % len(FRAMES)], oc, pi, oc_busy, pi_busy)
            index += 1
            was_busy = True
            time.sleep(FRAME_INTERVAL)


if __name__ == "__main__":
    main()

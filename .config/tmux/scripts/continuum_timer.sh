#!/bin/sh
# Save the tmux layout on a real clock instead of on every status redraw.
#
# tmux-continuum triggers its autosave by putting `#(continuum_save.sh)` in
# status-right: it uses the status refresh as a timer, and therefore forks bash
# (plus three helper scripts) every single redraw. That is ~2 ms, affordable at
# status-interval 10 and ruinous once the spinner redraws at 8 fps. Its own
# interpolation is disabled in plugins/tmux-continuum/continuum.tmux; this loop
# performs the same save on the same interval, from one sleeping process.
#
# The save script keeps its own bookkeeping (it bails out if nothing changed or
# the interval has not elapsed), so running it here is the same call the plugin
# used to make, minus the fork storm.
set -u

SAVE="$HOME/.config/tmux/plugins/tmux-continuum/scripts/continuum_save.sh"
INTERVAL=$(tmux show-options -gv @continuum-save-interval 2>/dev/null || echo 15)
case "$INTERVAL" in ""|*[!0-9]*) INTERVAL=15 ;; esac
[ "$INTERVAL" -gt 0 ] || INTERVAL=15

while tmux has-session 2>/dev/null; do
    sleep $((INTERVAL * 60))
    "$SAVE" >/dev/null 2>&1
done

#!/usr/bin/env bash
# Dropbox control helper for the waybar module.
# Usage: dropbox-control.sh [toggle|login]
# Performs the action and signals waybar to refresh the module immediately.
set -euo pipefail

action="${1:-toggle}"
SIGNAL_DONE=false

refresh_waybar() {
  # waybar module declares "signal": 8 -> SIGRTMIN+8 triggers an immediate re-exec.
  if kill -RTMIN+8 "$(pgrep -x waybar | head -n1)" 2>/dev/null; then
    SIGNAL_DONE=true
  fi
}

case "$action" in
  toggle)
    # pgrep is the source of truth: `dropbox-cli running` exits 1 when running
    # and 0 when not (inverted from every other CLI on the planet).
    if pgrep -x dropbox >/dev/null 2>&1; then
      if timeout 10 dropbox-cli stop >/dev/null 2>&1; then
        notify-send -a "Dropbox" "󰇣 Syncing paused" || true
      else
        notify-send -u critical -a "Dropbox" "Failed to pause Dropbox" || true
      fi
    else
      # Launch headless (no display vars) so dropboxd does not register a
      # duplicate tray icon next to the waybar module.
      if timeout 10 env -u DISPLAY -u WAYLAND_DISPLAY dropbox-cli start >/dev/null 2>&1; then
        notify-send -a "Dropbox" "󰇣 Syncing resumed" || true
      else
        notify-send -u critical -a "Dropbox" "Failed to start Dropbox" || true
      fi
    fi
    ;;
  login)
    output=$(timeout 15 env -u DISPLAY -u WAYLAND_DISPLAY dropbox-cli start 2>&1 || true)
    url=$(printf '%s' "$output" | grep -oE 'https?://[^ ]+' | head -n1 || true)
    if [[ -n "$url" ]]; then
      xdg-open "$url" >/dev/null 2>&1 || true
      notify-send -a "Dropbox" "Login page opened in browser" || true
    else
      notify-send -a "Dropbox" "Dropbox responded, no login needed" || true
    fi
    ;;
  *)
    printf 'usage: %s [toggle|login]\n' "$0" >&2
    exit 1
    ;;
esac

refresh_waybar
exit 0

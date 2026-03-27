#!/usr/bin/env bash
set -euo pipefail

WINDOW="calendar-window"
EWW_DIR="$HOME/.config/eww/calendar"

if eww -c "$EWW_DIR" active-windows 2>/dev/null | grep -q "${WINDOW}"; then
    eww -c "$EWW_DIR" close "$WINDOW"
else
    "$HOME/.config/waybar/scripts/calendar_daemon.py" --init
    eww -c "$EWW_DIR" open "$WINDOW"
fi

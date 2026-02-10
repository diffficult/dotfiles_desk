#!/bin/bash

# Script to restart mpvpaper when monitors wake from DPMS suspend
# This ensures video playback resumes smoothly after screen wake

PID_FILE="/tmp/aerial-mpvpaper.pid"
PLAYLIST_FILE="/tmp/aerial-playlist.m3u"

# Turn monitors back on
hyprctl dispatch dpms on

# If hyprlock is running and we have a playlist, restart mpvpaper
if pgrep -x hyprlock > /dev/null && [ -f "$PLAYLIST_FILE" ] && [ -s "$PLAYLIST_FILE" ]; then
    # Kill old mpvpaper instance and all children aggressively
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        pkill -9 -P "$OLD_PID" 2>/dev/null
        kill -9 "$OLD_PID" 2>/dev/null
    fi
    pkill -9 -f "mpvpaper.*aerial-playlist" 2>/dev/null
    pkill -9 mpvpaper 2>/dev/null

    # Restart mpvpaper with the same playlist
    sleep 0.3
    mpvpaper -l overlay -f -o "no-audio shuffle loop-playlist=inf keep-open=no stop-screensaver=no no-osd-bar" '*' "$PLAYLIST_FILE" &
    MPV_PID=$!
    echo "$MPV_PID" > "$PID_FILE"
fi

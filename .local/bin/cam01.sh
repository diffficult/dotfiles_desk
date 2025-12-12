#!/bin/bash

# 1. Launch mpv
mpv rtsp://admin:admin1234admin@10.0.10.81:554/Channels/101 --no-resume-playback &
PID=$!

# 2. Wait for the mpv window to exist and grab its window ID
WIN_ID=""
while [ -z "$WIN_ID" ]; do
    # wmctrl fields: 1=WINID 3=PID
    WIN_ID=$(wmctrl -lp | awk -v pid="$PID" '$3 == pid {print $1; exit}')
    sleep 0.1
done

# 3. Focus the window (so QuickTile acts on it)
wmctrl -ia "$WIN_ID"

# 4. Remove maximization/fullscreen if any (otherwise resizing can be ignored)
wmctrl -ir "$WIN_ID" -b remove,maximized_vert,maximized_horz,fullscreen

# Small delay to let the WM apply changes
sleep 0.1

# 5. Move to top-left using QuickTile
quicktile top-left

# 6. Compute 40% of the screen size (simpler & robust);
#    If you want per-monitor sizing later, we can refine this.
SCREEN_RES=$(xrandr | awk '/\*/ {print $1; exit}')   # e.g. "1920x1080"
SCREEN_W=${SCREEN_RES%x*}
SCREEN_H=${SCREEN_RES#*x}

WIDTH=$(( SCREEN_W * 40 / 100 ))
HEIGHT=$(( SCREEN_H * 40 / 100 ))

# 7. Resize the window but KEEP its current position:
#    Use -1 for X/Y so wmctrl does not move it, only resizes.
wmctrl -ir "$WIN_ID" -e "0,-1,-1,$WIDTH,$HEIGHT"


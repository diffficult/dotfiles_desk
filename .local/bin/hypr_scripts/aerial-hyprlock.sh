#!/bin/bash

VIDEO_DIR="/opt/ATV4"
SCRIPT_DIR="/home/rx/.local/bin/hypr_scripts"
NIGHT_FILE="$SCRIPT_DIR/night.txt"
DAY_FILE="$SCRIPT_DIR/day.txt"
PID_FILE="/tmp/aerial-mpvpaper.pid"
PLAYLIST_FILE="/tmp/aerial-playlist.m3u"
SWWW_STATE_FILE="/tmp/aerial-swww-running"
WALLPAPER_SAVE="/tmp/aerial-wallpapers.txt"
LOCK_FILE="/tmp/aerial-hyprlock.lock"

# Prevent multiple instances from running simultaneously
if [ -f "$LOCK_FILE" ]; then
    # Check if the process from lock file is actually running
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        echo "Lock screen already running (PID: $LOCK_PID)" >&2
        exit 0
    fi
    # Stale lock file, remove it
    rm -f "$LOCK_FILE"
fi

# Create lock file with our PID
echo $$ > "$LOCK_FILE"

# Save current swww wallpapers per-monitor BEFORE doing anything
if pgrep -x swww-daemon > /dev/null; then
    swww query > "$WALLPAPER_SAVE" 2>/dev/null
    echo "swww-running" > "$SWWW_STATE_FILE"
else
    rm -f "$SWWW_STATE_FILE" "$WALLPAPER_SAVE"
fi

# Kill any existing mpvpaper and related processes
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        # Kill the whole process group to get all child processes
        pkill -9 -P "$OLD_PID" 2>/dev/null
        kill -9 "$OLD_PID" 2>/dev/null
    fi
    rm -f "$PID_FILE"
fi

# Kill ALL mpvpaper and their mpv children aggressively
pkill -9 -f "mpvpaper.*aerial-playlist" 2>/dev/null
pkill -9 mpvpaper 2>/dev/null

# Also kill any orphaned mpv processes that might be playing aerial videos
# This catches mpv instances whose parent mpvpaper died without cleanup
pkill -9 -f "mpv.*aerial-playlist" 2>/dev/null
sleep 0.2

# Determine time-based video list
HOUR=$(date +%H)
if [ "$HOUR" -ge 21 ] || [ "$HOUR" -lt 6 ]; then
    SOURCE_FILE="$NIGHT_FILE"
else
    SOURCE_FILE="$DAY_FILE"
fi

# Build playlist from available videos
> "$PLAYLIST_FILE"  # Clear playlist file
while IFS= read -r video; do
    if [ -f "$VIDEO_DIR/$video" ]; then
        echo "$VIDEO_DIR/$video" >> "$PLAYLIST_FILE"
    fi
done < "$SOURCE_FILE"

# Verify we have videos
if [ ! -s "$PLAYLIST_FILE" ]; then
    echo "Error: No videos found" >&2
    exit 1
fi

# Start mpvpaper FIRST (before killing swww) to minimize transition flash
# Pass playlist file directly as video argument - mpv auto-detects .m3u format
# keep-open=no overrides user's mpv.conf to prevent pausing at end of videos
# stop-screensaver=no allows DPMS to trigger even while videos play
mpvpaper -l overlay -f -o "no-audio shuffle loop-playlist=inf keep-open=no stop-screensaver=no no-osd-bar" '*' "$PLAYLIST_FILE" &
MPV_PID=$!
echo "$MPV_PID" > "$PID_FILE"

# Give mpvpaper time to initialize and render first frame
sleep 0.8

# NOW kill swww-daemon (mpvpaper is already rendering, seamless transition)
if [ -f "$SWWW_STATE_FILE" ]; then
    pkill -9 swww-daemon 2>/dev/null
    sleep 0.2
fi

# Start hyprlock (blocking)
hyprlock --config ~/.config/hyprlock/hyprlock.conf

# Cleanup when hyprlock exits
# Kill mpvpaper and all its children
if [ -n "$MPV_PID" ]; then
    pkill -9 -P "$MPV_PID" 2>/dev/null
    kill -9 "$MPV_PID" 2>/dev/null
fi
pkill -9 -f "mpvpaper.*aerial-playlist" 2>/dev/null
pkill -9 mpvpaper 2>/dev/null

# Kill any remaining orphaned mpv processes playing aerial videos
pkill -9 -f "mpv.*aerial-playlist" 2>/dev/null
sleep 0.3

# Extra safety: kill ALL mpv processes (in case playlist pattern doesn't match)
# Only do this if we're sure no other mpv usage is happening
pkill -9 mpv 2>/dev/null

rm -f "$PID_FILE" "$LOCK_FILE"

# Restore swww-daemon and per-monitor wallpapers if it was running before
if [ -f "$SWWW_STATE_FILE" ]; then
    swww-daemon &
    sleep 0.5  # Wait for daemon to initialize

    # Restore per-monitor wallpapers from saved state
    if [ -f "$WALLPAPER_SAVE" ]; then
        while IFS= read -r line; do
            # Parse: "DP-1: image: /path/to/wallpaper.jpg"
            if [[ "$line" =~ ^([^:]+):[[:space:]]*image:[[:space:]]*(.+)$ ]]; then
                monitor="${BASH_REMATCH[1]}"
                wallpaper="${BASH_REMATCH[2]}"

                # Restore wallpaper for this specific monitor
                if [ -f "$wallpaper" ]; then
                    swww img -o "$monitor" "$wallpaper" --transition-type none 2>/dev/null
                fi
            fi
        done < "$WALLPAPER_SAVE"
        rm -f "$WALLPAPER_SAVE"
    fi

    rm -f "$SWWW_STATE_FILE"
fi

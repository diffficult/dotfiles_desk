#!/bin/bash

VIDEO_DIR="/opt/ATV4"
SCRIPT_DIR="/home/rx/.local/bin/hypr_scripts"
NIGHT_FILE="$SCRIPT_DIR/night.txt"
DAY_FILE="$SCRIPT_DIR/day.txt"
PID_FILE="/tmp/aerial-mpvpaper.pid"
PLAYLIST_FILE="/tmp/aerial-playlist.m3u"
SWWW_STATE_FILE="/tmp/aerial-awww-running"
WALLPAPER_SAVE="/tmp/aerial-wallpapers.txt"
LOCK_FILE="/tmp/aerial-hyprlock.lock"
LOG_FILE="/tmp/aerial-hyprlock.log"
LOCK_ACTIVE=0
RESTORE_SWWW=0

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

cleanup() {
    local exit_code=$?

    if [ "$LOCK_ACTIVE" -ne 1 ]; then
        return
    fi

    log "cleanup starting (exit=$exit_code)"

    if [ -f "$PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            pkill -9 -P "$old_pid" 2>/dev/null
            kill -9 "$old_pid" 2>/dev/null
        fi
    fi

    pkill -9 -f "mpvpaper.*aerial-playlist" 2>/dev/null
    pkill -9 mpvpaper 2>/dev/null
    pkill -9 -f "mpv.*aerial-playlist" 2>/dev/null
    sleep 0.3

    rm -f "$PID_FILE" "$LOCK_FILE"

    if [ "$RESTORE_SWWW" -eq 1 ] && [ -f "$SWWW_STATE_FILE" ]; then
        if ! pgrep -x awww-daemon > /dev/null; then
            log "restarting awww-daemon"
            awww-daemon &
            sleep 0.5
        else
            log "awww-daemon already running during cleanup"
        fi

        if [ -f "$WALLPAPER_SAVE" ]; then
            while IFS= read -r line; do
                if [[ "$line" =~ ^([^:]+):[[:space:]]*image:[[:space:]]*(.+)$ ]]; then
                    local monitor wallpaper
                    monitor="${BASH_REMATCH[1]}"
                    wallpaper="${BASH_REMATCH[2]}"

                    if [ -f "$wallpaper" ]; then
                        awww img -o "$monitor" "$wallpaper" --transition-type none 2>/dev/null
                        log "restored wallpaper on $monitor"
                    else
                        log "skipped missing wallpaper for $monitor: $wallpaper"
                    fi
                fi
            done < "$WALLPAPER_SAVE"
            rm -f "$WALLPAPER_SAVE"
        fi

        rm -f "$SWWW_STATE_FILE"
    else
        rm -f "$WALLPAPER_SAVE"
    fi

    log "cleanup finished"
}

trap cleanup EXIT HUP INT TERM

# Prevent multiple instances from running simultaneously
if [ -f "$LOCK_FILE" ]; then
    # Check if the process from lock file is actually running
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
        log "lockscreen already running with PID $LOCK_PID"
        echo "Lock screen already running (PID: $LOCK_PID)" >&2
        exit 0
    fi
    # Stale lock file, remove it
    rm -f "$LOCK_FILE"
fi

# Create lock file with our PID
echo $$ > "$LOCK_FILE"
LOCK_ACTIVE=1
log "lockscreen start PID $$"

# Save current awww wallpapers per-monitor BEFORE doing anything
if pgrep -x awww-daemon > /dev/null; then
    awww query > "$WALLPAPER_SAVE" 2>/dev/null
    echo "awww-running" > "$SWWW_STATE_FILE"
    RESTORE_SWWW=1
    log "saved current awww wallpaper state"
else
    rm -f "$SWWW_STATE_FILE" "$WALLPAPER_SAVE"
    log "awww-daemon was not running before lock"
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
    log "no videos found in playlist source"
    echo "Error: No videos found" >&2
    exit 1
fi

# Start mpvpaper FIRST (before killing awww) to minimize transition flash
# Pass playlist file directly as video argument - mpv auto-detects .m3u format
# keep-open=no overrides user's mpv.conf to prevent pausing at end of videos
# stop-screensaver=no allows DPMS to trigger even while videos play
mpvpaper -l overlay -f -o "no-audio shuffle loop-playlist=inf keep-open=no stop-screensaver=no no-osd-bar" '*' "$PLAYLIST_FILE" &
MPV_PID=$!
echo "$MPV_PID" > "$PID_FILE"
log "started mpvpaper with PID $MPV_PID"

# Give mpvpaper time to initialize and render first frame
sleep 0.8

# NOW kill awww-daemon (mpvpaper is already rendering, seamless transition)
if [ -f "$SWWW_STATE_FILE" ]; then
    log "stopping awww-daemon for lock overlay"
    pkill -9 awww-daemon 2>/dev/null
    sleep 0.2
fi

# Start hyprlock (blocking)
log "starting hyprlock"
hyprlock --config ~/.config/hyprlock/hyprlock.conf
log "hyprlock exited"

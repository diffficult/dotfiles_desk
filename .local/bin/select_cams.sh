#!/bin/bash

########################################
# CONFIG
########################################

# Monitor to use (xrandr output name)
# e.g. "DP-0" (left), "DP-2" (right primary), etc.
TARGET_OUTPUT="DP-0"

# Region size as percentage of that monitor
REGION_WIDTH_PCT=40    # % of monitor width
REGION_HEIGHT_PCT=50   # % of monitor height

# Optional margins inside the chosen corner (pixels)
MARGIN_X=0
MARGIN_Y=0

# Maximum number of feeds allowed at once
MAX_FEEDS=4

# Common mpv options
MPV_OPTS="--no-keepaspect-window --video-aspect-override=16:9 --no-resume-playback"

# Base RTSP URL (channel is filled in as 01..16)
RTSP_BASE="rtsp://admin:888888@192.168.3.30:554/cam/realmonitor?channel=%s&subtype=0"

# rofi command:
# -dmenu        : dmenu mode
# -multi-select : allow multi selection
# -kb-accept-alt "space" : use SPACE to toggle selection
# -kb-row-tab ""         : disable default row-tab to avoid conflicts
# -ballot-*              : ASCII indicators so they always show
ROFI_CMD='rofi -dmenu -i -multi-select -kb-accept-alt "space" -kb-row-tab "" -ballot-selected-str "[x] " -ballot-unselected-str "[ ] "'

########################################
# FUNCTIONS
########################################

die() {
    echo "Error: $*" >&2
    exit 1
}

get_monitor_geom() {
    local mon="$1"
    local geom

    geom=$(xrandr | awk -v mon="$mon" '
        $1 == mon && $2 == "connected" {
            for (i = 3; i <= NF; i++) {
                if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                    print $i;
                    exit;
                }
            }
        }
    ')

    [ -n "$geom" ] || die "Could not determine geometry for monitor $mon"
    echo "$geom"
}

# Wait for a window belonging to a PID, return WIN_ID
get_win_id_for_pid() {
    local pid="$1"
    local wid=""
    while [ -z "$wid" ]; do
        wid=$(wmctrl -lp | awk -v p="$pid" '$3 == p {print $1; exit}')
        sleep 0.1
    done
    echo "$wid"
}

########################################
# STEP 1: CHOOSE FEEDS (ROFI MULTI-SELECT)
########################################

CAM_LIST=$(
    printf '%s\n' \
        "01   " \
        "02   " \
        "03   " \
        "04   " \
        "05   " \
        "06   " \
        "07   " \
        "08   " \
        "09   " \
        "10   " \
        "11   " \
        "12   " \
        "13   " \
        "14   " \
        "15   " \
        "16   "
)

# shellcheck disable=SC2086
selection=$(echo "$CAM_LIST" | eval $ROFI_CMD -p "Seleccionar cámaras") || exit 0

mapfile -t SEL_LINES <<< "$selection"

SELECTED_IDS=()
for line in "${SEL_LINES[@]}"; do
    # first field is the ID
    cam_id=$(echo "$line" | awk '{print $1}')
    if [[ "$cam_id" =~ ^[0-9]{1,2}$ ]]; then
        # zero-pad 1-digit IDs (1 -> 01, etc.)
        printf -v cam_id "%02d" "$cam_id"
        SELECTED_IDS+=("$cam_id")
    fi
done

[ "${#SELECTED_IDS[@]}" -ge 1 ] || die "No cameras selected."

# Enforce MAX_FEEDS
if [ "${#SELECTED_IDS[@]}" -gt "$MAX_FEEDS" ]; then
    echo "Selected more than $MAX_FEEDS cameras, using the first $MAX_FEEDS." >&2
    SELECTED_IDS=("${SELECTED_IDS[@]:0:$MAX_FEEDS}")
fi

########################################
# STEP 2: CHOOSE CORNER (ROFI SINGLE-SELECT)
########################################

CORNER_MENU=$(
    printf '%s\n' \
        "󰧄 esquina superior izquierda" \
        "󰧆 esquina superior derecha" \
        "󰦸 esquina inferior izquierda" \
        "󰦺 esquina inferior derecha"
)

corner_sel=$(echo "$CORNER_MENU" | eval $ROFI_CMD -p "Ubicación") || exit 0

corner=""
case "$corner_sel" in
    "󰧄 esquina superior izquierda") corner="top-left" ;;
    "󰧆 esquina superior derecha")   corner="top-right" ;;
    "󰦸 esquina inferior izquierda") corner="bottom-left" ;;
    "󰦺 esquina inferior derecha")   corner="bottom-right" ;;
    *) die "Invalid corner selection." ;;
esac

########################################
# STEP 3: MONITOR GEOMETRY & REGION
########################################

MON_GEOM=$(get_monitor_geom "$TARGET_OUTPUT")
# MON_GEOM: e.g. 2560x1440+0+0
read MON_W MON_H MON_X MON_Y <<< "$(echo "$MON_GEOM" | sed -E 's/([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)/\1 \2 \3 \4/')"

REGION_W=$(( MON_W * REGION_WIDTH_PCT / 100 ))
REGION_H=$(( MON_H * REGION_HEIGHT_PCT / 100 ))

case "$corner" in
    top-left)
        REGION_X=$(( MON_X + MARGIN_X ))
        REGION_Y=$(( MON_Y + MARGIN_Y ))
        ;;
    top-right)
        REGION_X=$(( MON_X + MON_W - REGION_W - MARGIN_X ))
        REGION_Y=$(( MON_Y + MARGIN_Y ))
        ;;
    bottom-left)
        REGION_X=$(( MON_X + MARGIN_X ))
        REGION_Y=$(( MON_Y + MON_H - REGION_H - MARGIN_Y ))
        ;;
    bottom-right)
        REGION_X=$(( MON_X + MON_W - REGION_W - MARGIN_X ))
        REGION_Y=$(( MON_Y + MON_H - REGION_H - MARGIN_Y ))
        ;;
    *)
        die "Unexpected corner value: $corner"
        ;;
esac

########################################
# STEP 4: PER-FEED WINDOW GRID INSIDE REGION
########################################

num_feeds=${#SELECTED_IDS[@]}

WIN_XS=()
WIN_YS=()
WIN_WS=()
WIN_HS=()

if [ "$num_feeds" -eq 1 ]; then
    WIN_WS[0]=$REGION_W
    WIN_HS[0]=$REGION_H
    WIN_XS[0]=$REGION_X
    WIN_YS[0]=$REGION_Y

elif [ "$num_feeds" -eq 2 ]; then
    half_w=$(( REGION_W / 2 ))
    half_h=$REGION_H

    WIN_WS=( "$half_w" "$half_w" )
    WIN_HS=( "$half_h" "$half_h" )
    WIN_XS=( "$REGION_X" $(( REGION_X + half_w )) )
    WIN_YS=( "$REGION_Y" "$REGION_Y" )

else
    half_w=$(( REGION_W / 2 ))
    half_h=$(( REGION_H / 2 ))

    WIN_WS=( "$half_w" "$half_w" "$half_w" "$half_w" )
    WIN_HS=( "$half_h" "$half_h" "$half_h" "$half_h" )

    WIN_XS=(
        "$REGION_X"
        $(( REGION_X + half_w ))
        "$REGION_X"
        $(( REGION_X + half_w ))
    )
    WIN_YS=(
        "$REGION_Y"
        "$REGION_Y"
        $(( REGION_Y + half_h ))
        $(( REGION_Y + half_h ))
    )
fi

########################################
# STEP 5: LAUNCH MPV WINDOWS AND PLACE THEM
########################################

PIDS=()
WIN_IDS=()

# Launch feeds
for cam_id in "${SELECTED_IDS[@]}"; do
    # Build URL from base pattern and channel (cam_id)
    url=$(printf "$RTSP_BASE" "$cam_id")
    mpv $MPV_OPTS "$url" &
    PIDS+=($!)
    sleep 0.1
done

[ "${#PIDS[@]}" -ge 1 ] || die "No valid cameras launched."

# Resolve windows
for pid in "${PIDS[@]}"; do
    WIN_IDS+=( "$(get_win_id_for_pid "$pid")" )
done

# Apply geometry
for i in "${!WIN_IDS[@]}"; do
    WID="${WIN_IDS[$i]}"

    [ "$i" -lt "${#WIN_XS[@]}" ] || break

    X="${WIN_XS[$i]}"
    Y="${WIN_YS[$i]}"
    W="${WIN_WS[$i]}"
    H="${WIN_HS[$i]}"

    wmctrl -ia "$WID"
    wmctrl -ir "$WID" -b remove,maximized_vert,maximized_horz,fullscreen
    sleep 0.05
    wmctrl -ir "$WID" -e "0,$X,$Y,$W,$H"
done

exit 0


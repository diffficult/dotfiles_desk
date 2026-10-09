#!/usr/bin/env bash
# ============================================================================
# ELECOM Huge TrackBall button remapping for Wayland using evsieve
# ============================================================================
#
# The script remains in the foreground and supervises evsieve. If the
# trackball is unplugged, reset, or re-enumerated, evsieve exits and this
# script waits for the stable by-id link to return before starting it again.

DEVICE_LINK_GLOB="/dev/input/by-id/*ELECOM*TrackBall*event-mouse"
VIRTUAL_DEVICE_NAME="ELECOM-Huge-Remapped"
LOG_FILE="/tmp/trackball-remap.log"
RETRY_DELAY=2
DEBUG=false

EVSIEVE_PID=""
STOP_REQUESTED=false

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

find_device() {
    local link
    local device
    local candidates=()

    shopt -s nullglob
    candidates=( $DEVICE_LINK_GLOB )
    shopt -u nullglob

    for link in "${candidates[@]}"; do
        [[ -e "$link" ]] || continue
        device="$(readlink -f -- "$link")" || continue
        [[ -e "$device" ]] || continue
        printf '%s\n' "$device"
        return 0
    done

    return 1
}

request_stop() {
    STOP_REQUESTED=true
    if [[ -n "$EVSIEVE_PID" ]]; then
        kill "$EVSIEVE_PID" 2>/dev/null || true
    fi
}

trap request_stop INT TERM

EVSIEVE_BIN="$(command -v evsieve || true)"
if [[ -z "$EVSIEVE_BIN" ]]; then
    log "ERROR: evsieve not found; install it before starting this service"
    exit 1
fi

log "Starting ELECOM trackball remapping supervisor..."
LAST_DEVICE="waiting"

while true; do
    DEVICE="$(find_device || true)"

    if [[ -z "$DEVICE" ]]; then
        if [[ "$LAST_DEVICE" != "waiting" ]]; then
            log "ELECOM trackball not present; waiting for hotplug..."
            LAST_DEVICE="waiting"
        fi
        sleep "$RETRY_DELAY"
        continue
    fi

    if [[ "$LAST_DEVICE" != "$DEVICE" ]]; then
        log "Found trackball: $DEVICE"
        LAST_DEVICE="$DEVICE"
    fi

    # Confirmed physical mappings:
    # - Back 275    -> Right click 273
    # - Forward 276 -> Left click 272
    # - Fn1 277     -> Left click 272
    # - Fn2 278     -> Middle click 274
    # - Fn3 279     -> unchanged; Hyprland handles native scrolling
    EVSIEVE_CMD=(
        "$EVSIEVE_BIN"
        --input "$DEVICE" domain=trackball grab
        --map btn:left btn:left
        --map btn:right btn:right
        --map btn:middle btn:middle
        --map btn:%275 btn:%273
        --map btn:%276 btn:%272
        --map btn:%277 btn:%272
        --map btn:%278 btn:%274
        --output "name=$VIRTUAL_DEVICE_NAME"
    )

    if [[ "$DEBUG" == true ]]; then
        EVSIEVE_CMD+=(--print)
    fi

    log "Starting evsieve with button remapping..."
    log "Command: ${EVSIEVE_CMD[*]}"
    "${EVSIEVE_CMD[@]}" >> "$LOG_FILE" 2>&1 &
    EVSIEVE_PID=$!

    log "Trackball remapping active (PID: $EVSIEVE_PID)"
    log "Virtual device: $VIRTUAL_DEVICE_NAME"
    log "Mappings: Back->Right, Forward->Left, Fn1->Left, Fn2->Middle"
    log "Scroll: hold Fn3 while moving the trackball"

    wait "$EVSIEVE_PID"
    STATUS=$?
    EVSIEVE_PID=""
    LAST_DEVICE=""

    if [[ "$STOP_REQUESTED" == true ]]; then
        exit 0
    fi

    log "evsieve exited with status $STATUS; retrying in ${RETRY_DELAY}s"
    sleep "$RETRY_DELAY"
done

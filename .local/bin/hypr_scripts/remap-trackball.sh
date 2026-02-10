#!/bin/bash
# ============================================================================
# ELECOM Huge TrackBall Button Remapping for Wayland using evsieve
# ============================================================================
# Based on X11 config: ButtonMapping "1 2 3 4 5 6 7 8 3 1 2 12"
#
# X11 Button Mapping Translation:
# Position 1 (Left)     → 1 (Left)      - Pass through
# Position 2 (Middle)   → 2 (Middle)    - Pass through
# Position 3 (Right)    → 3 (Right)     - Pass through
# Position 4-7          → Scroll/Tilt   - Pass through (wheel events)
# Position 8 (Back)     → 3 (Middle)    - REMAP btn:275 → btn:274
# Position 9 (Forward)  → 1 (Left)      - REMAP btn:276 → btn:272
# Position 10 (Fn1)     → 2 (Middle)    - REMAP btn:277 → btn:274
# Position 11 (Fn2)     → 12            - REMAP btn:278 → btn:279
# Position 12 (Fn3)     → Scroll button - Handled by Hyprland config

# ============================================================================
# Configuration
# ============================================================================

# Device search patterns (adjust if needed)
DEVICE_NAME_PATTERN="HUGE TrackBall"
VIRTUAL_DEVICE_NAME="ELECOM-Huge-Remapped"

# Logging
LOG_FILE="/tmp/trackball-remap.log"
DEBUG=true  # Set to true to see all events

# ============================================================================
# Find Device
# ============================================================================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting trackball remapping..." | tee -a "$LOG_FILE"

# Try to find device using libinput
DEVICE=$(libinput list-devices 2>/dev/null | grep -A 5 "$DEVICE_NAME_PATTERN" | grep "Kernel:" | awk '{print $2}' | head -n 1)

# Fallback: search /dev/input/by-id/
if [ -z "$DEVICE" ]; then
    DEVICE=$(ls -1 /dev/input/by-id/*ELECOM*TrackBall* 2>/dev/null | head -n 1)
    if [ -n "$DEVICE" ]; then
        DEVICE=$(readlink -f "$DEVICE")
    fi
fi

# Error if not found
if [ -z "$DEVICE" ] || [ ! -e "$DEVICE" ]; then
    echo "ERROR: ELECOM HUGE TrackBall not found!" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Available input devices:" | tee -a "$LOG_FILE"
    libinput list-devices 2>/dev/null | grep "Device:" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Tip: Run 'libinput list-devices' to see all devices" | tee -a "$LOG_FILE"
    echo "     Run 'sudo evtest' to test button codes" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Found trackball: $DEVICE" | tee -a "$LOG_FILE"

# ============================================================================
# Check if evsieve is installed
# ============================================================================

if ! command -v evsieve &> /dev/null; then
    echo "ERROR: evsieve not found!" | tee -a "$LOG_FILE"
    echo "Install with: yay -S evsieve" | tee -a "$LOG_FILE"
    exit 1
fi

# ============================================================================
# Build evsieve command
# ============================================================================

EVSIEVE_CMD=(
    evsieve
    --input "$DEVICE" domain=trackball grab

    # Pass through standard buttons (no remapping needed)
    --map btn:left btn:left
    --map btn:right btn:right
    --map btn:middle btn:middle

    # Remap special buttons - CONFIRMED MAPPINGS
    # Based on evtest results:
    # - Back = BTN_SIDE (275) → Right Click (273)
    # - Forward = BTN_EXTRA (276) → Left Click (272)
    # - Fn1 = BTN_FORWARD (277) → Left Click (272)
    # - Fn2 = BTN_BACK (278) → Middle Click (274)
    # - Fn3 = BTN_TASK (279) → Toggle scroll mode

    --map btn:%275 btn:%273  # Back (BTN_SIDE) → Right Click (BTN_RIGHT)
    --map btn:%276 btn:%272  # Forward (BTN_EXTRA) → Left Click (BTN_LEFT)
    --map btn:%277 btn:%272  # Fn1 (BTN_FORWARD) → Left Click (BTN_LEFT)
    --map btn:%278 btn:%274  # Fn2 (BTN_BACK) → Middle Click (BTN_MIDDLE)

    # Scroll mode is now handled by Hyprland's native scroll_method = on_button_down
    # Fn3 button (BTN_TASK 279) is used as scroll_button in Hyprland config

    # Output to virtual device
    --output "name=$VIRTUAL_DEVICE_NAME"
)

# Add debug/print flag if enabled
if [ "$DEBUG" = true ]; then
    EVSIEVE_CMD+=(--print)
fi

# ============================================================================
# Run evsieve
# ============================================================================

echo "Starting evsieve with button remapping..." | tee -a "$LOG_FILE"
echo "Command: ${EVSIEVE_CMD[*]}" >> "$LOG_FILE"

# Check if we need sudo
if groups | grep -q '\binput\b'; then
    # User is in input group, try without sudo
    "${EVSIEVE_CMD[@]}" >> "$LOG_FILE" 2>&1 &
    EVSIEVE_PID=$!
else
    # Need sudo
    sudo "${EVSIEVE_CMD[@]}" >> "$LOG_FILE" 2>&1 &
    EVSIEVE_PID=$!
fi

# Wait a moment and check if process started
sleep 1

if ps -p $EVSIEVE_PID > /dev/null 2>&1; then
    echo "✓ Trackball remapping active (PID: $EVSIEVE_PID)" | tee -a "$LOG_FILE"
    echo "  Virtual device: $VIRTUAL_DEVICE_NAME" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Button mappings:" | tee -a "$LOG_FILE"
    echo "  - Back button    → Right Click" | tee -a "$LOG_FILE"
    echo "  - Forward button → Left Click" | tee -a "$LOG_FILE"
    echo "  - Fn1 button     → Left Click" | tee -a "$LOG_FILE"
    echo "  - Fn2 button     → Middle Click" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Scroll mode:" | tee -a "$LOG_FILE"
    echo "  - Hold Fn3 button to scroll (handled by Hyprland)" | tee -a "$LOG_FILE"
    echo "  - Move trackball while holding Fn3 to scroll" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "To stop: killall evsieve" | tee -a "$LOG_FILE"
else
    echo "✗ ERROR: evsieve failed to start" | tee -a "$LOG_FILE"
    echo "Check permissions or run with sudo" | tee -a "$LOG_FILE"
    exit 1
fi

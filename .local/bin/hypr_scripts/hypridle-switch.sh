#!/bin/bash

# Switches hypridle config based on time of day
# Night (10pm-9am): Lock @ 10min, Suspend @ +2min
# Day (9am-10pm): Lock @ 15min, Suspend @ +10min

HOUR=$(date +%H)
CONFIG_DIR="$HOME/.config/hypr"
ACTIVE_CONFIG="$CONFIG_DIR/hypridle.conf"

# Determine which config to use (22-23, 0-8 = night, 9-21 = day)
if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 9 ]; then
    TARGET_CONFIG="$CONFIG_DIR/hypridle-night.conf"
    MODE="night"
else
    TARGET_CONFIG="$CONFIG_DIR/hypridle-day.conf"
    MODE="day"
fi

# Check if we need to switch
CURRENT_TARGET=$(readlink -f "$ACTIVE_CONFIG" 2>/dev/null)
NEW_TARGET=$(readlink -f "$TARGET_CONFIG")

if [ "$CURRENT_TARGET" != "$NEW_TARGET" ]; then
    echo "Switching to $MODE mode config"
    ln -sf "$TARGET_CONFIG" "$ACTIVE_CONFIG"

    # Reload hypridle if it's running
    if pgrep -x hypridle > /dev/null; then
        pkill -SIGUSR1 hypridle 2>/dev/null || {
            # If SIGUSR1 doesn't work, restart hypridle
            pkill hypridle
            sleep 0.5
            hypridle &
        }
    fi
else
    echo "Already using $MODE mode config"
fi

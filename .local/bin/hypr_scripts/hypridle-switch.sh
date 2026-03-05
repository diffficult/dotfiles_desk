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

    # Restart via systemd — hypridle is managed as a proper user service.
    # Do NOT use pkill + uwsm/hypridle & here: backgrounded processes get killed
    # when systemd cleans up this service's cgroup after ExecStart exits.
    systemctl --user restart hypridle.service

    # Always wake monitors after a config switch. If monitors were in DPMS-off
    # when hypridle restarted, the new instance has no prior state and on-resume
    # will never fire. key_press_enables_dpms also won't fire when hyprlock has
    # the session locked (input goes to lock surface, not compositor pipeline).
    wlopm --on '*'
else
    echo "Already using $MODE mode config"
fi

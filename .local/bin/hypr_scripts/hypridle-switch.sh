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

    if pgrep -x hyprlock > /dev/null; then
        # Session is locked (user away). Don't restart hypridle — it must keep its
        # current DPMS state so on-resume fires when the user presses a key.
        # key_press_enables_dpms does NOT work with wlopm-managed outputs; only
        # hypridle's on-resume can wake the monitors. Restarting here would lose
        # the on-timeout state and leave monitors stuck off.
        # aerial-hyprlock.sh will restart hypridle after unlock so the new config
        # takes effect immediately when the user logs back in.
        echo "Session locked: symlink updated, hypridle restart deferred to unlock"
    else
        # No lock screen: wake monitors (in case they were off) and restart hypridle
        # with the new config. Monitors were off without a lock → safe to wake.
        wlopm --on '*'
        # Restart via systemd — hypridle is managed as a proper user service.
        # Do NOT use pkill + uwsm/hypridle & here: backgrounded processes get killed
        # when systemd cleans up this service's cgroup after ExecStart exits.
        systemctl --user restart hypridle.service
    fi
else
    echo "Already using $MODE mode config"
fi

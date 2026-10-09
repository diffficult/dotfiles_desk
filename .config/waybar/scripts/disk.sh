#!/usr/bin/env bash

set -euo pipefail
# Waybar Disk Module - Enhanced disk usage monitor
# Shows /home free space with detailed tooltip for all mounted drives

# One JSON escaper for every bar script (T7.2), sourced from this script's own
# directory so two scripts can never end up with two escapers. The fallback is
# the whole point of sourcing rather than inlining: Waybar renders nothing at
# all for a module that prints malformed JSON, so a missing escaper must be a
# visible error module, never an exit that leaves the bar blank.
json_lib="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/json.sh"
if [[ -r "$json_lib" ]]; then
    # shellcheck source=/dev/null  # runtime-resolved sibling; see json.sh
    source "$json_lib"
else
    echo '{"text":"N/A","tooltip":"json.sh not found next to the script","class":"error"}'
    exit 1
fi

# df is the one tool this module cannot work without; the rest are awk/sed, which
# POSIX guarantees. Without df the module reported "Failed to get disk info", which
# is true but says nothing about the cause.
if ! command -v df &>/dev/null; then
    echo '{"text":"N/A","tooltip":"df not installed","class":"error"}'
    exit 1
fi

# One `df -h /home` call, not two: the headline numbers and the tooltip row are the
# same df row and were being fetched separately. Keep the raw row and format it
# twice, so both still come from a single sample.
HOME_ROW=$(df -h /home 2>/dev/null | awk 'NR==2')

if [[ -z "$HOME_ROW" ]]; then
    echo '{"text":"N/A","tooltip":"Failed to get disk info","class":"error"}'
    exit 1
fi

# Parse /home info
HOME_INFO=$(printf '%s\n' "$HOME_ROW" | awk '{printf "%s|%s|%s|%s", $2, $3, $4, $5}')
IFS='|' read -r HOME_TOTAL HOME_USED HOME_FREE HOME_PERCENT <<< "$HOME_INFO"

# Whether /home is really its own filesystem. On a machine without a separate
# /home, `df -h /home` answers for / and this module has always presented the root
# filesystem as if it were home. Detect that instead of assuming it away. On a
# machine that does have a separate /home -- the machine this ships on -- nothing
# below the heading changes, and HOME_NOTE is empty.
HOME_MOUNT=$(printf '%s\n' "$HOME_ROW" | awk '{print $NF}')
if [[ "$HOME_MOUNT" == "/home" ]]; then
    HOME_NOTE=""
else
    HOME_NOTE=$'\n'"-- /home has no filesystem of its own; showing ${HOME_MOUNT}"
fi

# Parse metrics from single query
HOME_PERCENT_NUM="${HOME_PERCENT%\%}"  # Remove % sign for comparison

# Calculate free percentage for display and logic
HOME_FREE_PERCENT=$((100 - HOME_PERCENT_NUM))

# Available space-based color coding
COLOR_NORMAL="#cdd6f4"
COLOR_LOW="#a6da95"
COLOR_MODERATE="#fe640b"
COLOR_CRITICAL="#d20f39"

if [[ $HOME_FREE_PERCENT -le 10 ]]; then
    DISK_COLOR="$COLOR_CRITICAL"
    DISK_CLASS="critical"
elif [[ $HOME_FREE_PERCENT -le 40 ]]; then
    DISK_COLOR="$COLOR_MODERATE"
    DISK_CLASS="moderate"
elif [[ $HOME_FREE_PERCENT -le 60 ]]; then
    DISK_COLOR="$COLOR_LOW"
    DISK_CLASS="low"
else
    DISK_COLOR="$COLOR_NORMAL"
    DISK_CLASS="normal"
fi

# Emoji/Icon Selection
# EMOJI="💾"
ICON="" # Nerd Font Disk icon

# Build display text with Pango markup
if [[ "$DISK_CLASS" == "critical" ]]; then
    DISPLAY_TEXT="<span background='#d20f39' foreground='#232634'><b><span font_desc='JetBrainsMono Nerd Font 14'>${ICON}</span> <span font_desc='JetBrainsMono Nerd Font Bold 14'>${HOME_FREE_PERCENT}%</span></b></span>"
else
    DISPLAY_TEXT="<span font_desc='JetBrainsMono Nerd Font 14' color='${DISK_COLOR}'>${ICON}</span> <span font_desc='JetBrainsMono Nerd Font Bold 14' color='${DISK_COLOR}'>${HOME_FREE_PERCENT}%</span>"
fi

# Build detailed tooltip
TOOLTIP="${ICON} Disk Usage Report"$'\n\n'

# All mounted filesystems (excluding pseudo filesystems). This listing used to be
# taken twice: once into a FILESYSTEMS array that nothing ever read, and once to
# build OTHER_MOUNTS. The array was dead work on every refresh; the listing is now
# taken once and reused.
DF_ALL=$(df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null || true)

# Add root filesystem info
ROOT_INFO=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%-15s %6s  %6s  %6s  %5s", $1, $2, $3, $4, $5}')
if [[ -n "$ROOT_INFO" ]]; then
    TOOLTIP+="󰿠 Root (/)"$'\n'
    TOOLTIP+="└─ ${ROOT_INFO}"$'\n\n'
fi

# Add /home filesystem info, from the /home df row captured at the top
HOME_FULL_INFO=$(printf '%s\n' "$HOME_ROW" | awk '{printf "%-15s %6s  %6s  %6s  %5s", $1, $2, $3, $4, $5}')
if [[ -n "$HOME_FULL_INFO" ]]; then
    TOOLTIP+=" Home (/home)"$'\n'
    TOOLTIP+="└─ ${HOME_FULL_INFO}${HOME_NOTE}"$'\n\n'
fi

# Add other mounted drives (excluding /, /home, /boot, /boot/efi)
OTHER_MOUNTS=$(printf '%s\n' "$DF_ALL" | \
    awk 'NR>1 && $6!="/" && $6!="/home" && $6!="/boot" && $6!="/boot/efi" && $6!~/^\/run/ && $6!~/^\/dev/ && $6!~/^\/sys/ {
        printf "%-15s %6s  %6s  %6s  %5s  %s\n", $1, $2, $3, $4, $5, $6
    }')

if [[ -n "$OTHER_MOUNTS" ]]; then
    TOOLTIP+=" Other Mounts"$'\n'
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        MOUNT_POINT=$(echo "$line" | awk '{print $NF}')
        MOUNT_INFO=$(echo "$line" | awk '{printf "%-15s %6s  %6s  %6s  %5s", $1, $2, $3, $4, $5}')
        TOOLTIP+="├─ ${MOUNT_POINT}"$'\n'
        TOOLTIP+="│  └─ ${MOUNT_INFO}"$'\n'
    done <<< "$OTHER_MOUNTS"
    TOOLTIP+=$'\n'
fi

# Add legend
TOOLTIP+="󰄨 Legend"$'\n'
TOOLTIP+="└─ Device  Total  Used  Free  %Used"$'\n\n'

TOOLTIP+="󰯂 Actions"$'\n'
TOOLTIP+="└─ Click to open file manager"

# Output JSON for waybar
echo "{\"text\":$(wb_json_escape "${DISPLAY_TEXT}"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "${DISK_CLASS}")}"

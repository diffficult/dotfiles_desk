#!/usr/bin/env bash

set -euo pipefail
# Waybar CPU Module - Enhanced CPU monitor with detailed metrics
# Based on XFCE cpu.sh applet

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

# Check if sensors is available
if ! command -v sensors &>/dev/null; then
    echo '{"text":"N/A","tooltip":"lm-sensors not installed","class":"error"}'
    exit 0
fi

# Get CPU model name (single read, more efficient)
CPU_MODEL="$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"

# Get number of physical cores and threads
PHYSICAL_CORES="$(grep -E "^cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')"
THREADS="$(grep -c "^processor" /proc/cpuinfo || true)"

# Get CPU frequencies (in MHz) from /proc/cpuinfo - single awk call
mapfile -t CPU_FREQS < <(awk '/cpu MHz/{printf "%.0f\n", $4}' /proc/cpuinfo)

# Calculate average CPU frequency. `cpu MHz` is absent on every core in a VM and on
# most ARM boards, so the array can legitimately come back empty; dividing by its
# length then raised "division by 0", which left AVG_FREQ empty and the tooltip
# claiming "0.00 GHz" as if it had measured something. Degrade to the same "N/A"
# the range below already uses when cpufreq is missing.
TOTAL_FREQ=0
for freq in "${CPU_FREQS[@]}"; do
    ((TOTAL_FREQ += freq))
done
if [[ ${#CPU_FREQS[@]} -gt 0 ]]; then
    AVG_FREQ=$((TOTAL_FREQ / ${#CPU_FREQS[@]}))
    AVG_FREQ_GHZ=$(awk -v freq="$AVG_FREQ" 'BEGIN {printf "%.2f", freq / 1000}')
else
    AVG_FREQ_GHZ="N/A"
fi

# Get min/max frequencies from cpufreq
MIN_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || true)
MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || true)
if [[ -n "$MIN_FREQ" && -n "$MAX_FREQ" ]]; then
    MIN_FREQ_GHZ=$(awk -v freq="$MIN_FREQ" 'BEGIN {printf "%.2f", freq / 1000000}')
    MAX_FREQ_GHZ=$(awk -v freq="$MAX_FREQ" 'BEGIN {printf "%.2f", freq / 1000000}')
else
    MIN_FREQ_GHZ="N/A"
    MAX_FREQ_GHZ="N/A"
fi

# Get CPU governor
CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")

# Read `sensors` once. It used to be invoked four times -- once per temperature
# probe, plus once for the CCD sweep -- and every one of those invocations walks the
# whole hwmon tree. Sampling a socket's temperature is exactly the kind of reading
# that shifts between two calls, so the fallback chain was not just slow, it could
# mix a Tctl from one instant with a Tccd from another.
SENSORS_OUT=$(sensors 2>/dev/null)

# Get CPU temperature - robust parsing for AMD Ryzen (Tctl)
CPU_TEMP=$(printf '%s\n' "$SENSORS_OUT" | awk '/^Tctl:/ {print $2}' | tr -d '+°C' | head -1)
if [[ -z "$CPU_TEMP" ]]; then
    # Fallback to Tdie or other common temp sensors
    CPU_TEMP=$(printf '%s\n' "$SENSORS_OUT" | awk '/^Tdie:/ {print $2}' | tr -d '+°C' | head -1)
fi
if [[ -z "$CPU_TEMP" ]]; then
    # Final fallback to Core 0
    CPU_TEMP=$(printf '%s\n' "$SENSORS_OUT" | awk '/^Core 0:/ {print $3}' | tr -d '+°C' | head -1)
fi
if [[ -z "$CPU_TEMP" ]]; then
    CPU_TEMP="N/A"
fi

# Get per-core temperatures (for AMD Ryzen with CCDs)
CORE_TEMPS=$(printf '%s\n' "$SENSORS_OUT" | awk '/^Tccd[0-9]:/ {printf "%s: %s  ", $1, $2}' | sed 's/://g')

# Get CPU utilization - calculate from idle percentage
CPU_IDLE=$(top -bn1 | awk '/^%Cpu\(s\):/ {print $8}')
if [[ -n "$CPU_IDLE" ]]; then
    CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN {printf "%.1f", 100 - idle}')
else
    CPU_USAGE="N/A"
fi

# Get load average
LOAD_AVG=$(awk '{printf "%s %s %s", $1, $2, $3}' /proc/loadavg)

# Temperature-based color coding
COLOR_NORMAL="#cdd6f4"
COLOR_LOW="#a6da95"
COLOR_MODERATE="#fe640b"
COLOR_HIGH="#e64553"
COLOR_CRITICAL="#d20f39"

if [[ "$CPU_TEMP" != "N/A" ]]; then
    TEMP_INT=$(printf "%.0f" "$CPU_TEMP")
    if [[ $TEMP_INT -ge 100 ]]; then
        TEMP_COLOR="$COLOR_CRITICAL"
        TEMP_CLASS="critical"
    elif [[ $TEMP_INT -ge 90 ]]; then
        TEMP_COLOR="$COLOR_HIGH"
        TEMP_CLASS="high"
    elif [[ $TEMP_INT -ge 80 ]]; then
        TEMP_COLOR="$COLOR_MODERATE"
        TEMP_CLASS="moderate"
    elif [[ $TEMP_INT -ge 70 ]]; then
        TEMP_COLOR="$COLOR_LOW"
        TEMP_CLASS="low"
    else
        TEMP_COLOR="$COLOR_NORMAL"
        TEMP_CLASS="normal"
    fi
else
    TEMP_COLOR="$COLOR_NORMAL"
    TEMP_CLASS="unknown"
fi

# Emoji/Icon Selection
# EMOJI="🖥"
ICON=" " # Nerd Font CPU icon

# Build display text with Pango markup for color
#DISPLAY_TEXT="<span color='${TEMP_COLOR}'>${ICON} ${CPU_TEMP}°C</span>"
DISPLAY_TEXT="<span font_desc='JetBrainsMono Nerd Font 14' color='${TEMP_COLOR}'>${ICON}</span> <span font_desc='JetBrainsMono Nerd Font Bold 14' color='${TEMP_COLOR}'>${CPU_TEMP}°C</span>"

# Build detailed tooltip
TOOLTIP="${ICON} ${CPU_MODEL}"$'\n\n'
TOOLTIP+=" Hardware"$'\n'
TOOLTIP+="├─ Cores/Threads: ${PHYSICAL_CORES}C / ${THREADS}T"$'\n'
TOOLTIP+="├─ Frequency: ${AVG_FREQ_GHZ} GHz (avg)"$'\n'
TOOLTIP+="├─ Range: ${MIN_FREQ_GHZ} - ${MAX_FREQ_GHZ} GHz"$'\n'
TOOLTIP+="└─ Governor: ${CPU_GOVERNOR}"$'\n\n'

TOOLTIP+="󰄧 Performance"$'\n'
TOOLTIP+="├─ CPU Usage: ${CPU_USAGE}%"$'\n'
TOOLTIP+="├─ Temperature: ${CPU_TEMP}°C"$'\n'
if [[ -n "$CORE_TEMPS" ]]; then
    TOOLTIP+="├─ Core Temps: ${CORE_TEMPS}"$'\n'
fi
TOOLTIP+="└─ Load Average: ${LOAD_AVG}"$'\n\n'

TOOLTIP+="󰳾 Actions"$'\n'
TOOLTIP+="└─ Click to open task manager"

# Output JSON for waybar
echo "{\"text\":$(wb_json_escape "${DISPLAY_TEXT}"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "${TEMP_CLASS}")}"

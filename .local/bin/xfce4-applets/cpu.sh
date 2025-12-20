#!/usr/bin/env bash

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Size used for the icons is 24x24 (16x16 is also ok for a smaller panel)
readonly ICON="${DIR}/icons/cpu.png"

# Check if sensors is available
if ! command -v sensors &>/dev/null; then
  echo "<txt>CPU: N/A</txt>"
  echo "<tool>lm-sensors not installed</tool>"
  exit 0
fi

# Get CPU model name (single read, more efficient)
readonly CPU_MODEL="$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"

# Get number of physical cores and threads
readonly PHYSICAL_CORES="$(grep -E "^cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')"
readonly THREADS="$(grep -c "^processor" /proc/cpuinfo)"

# Get CPU frequencies (in MHz) from /proc/cpuinfo - single awk call
mapfile -t CPU_FREQS < <(awk '/cpu MHz/{printf "%.0f\n", $4}' /proc/cpuinfo)

# Calculate average CPU frequency
TOTAL_FREQ=0
for freq in "${CPU_FREQS[@]}"; do
  ((TOTAL_FREQ += freq))
done
AVG_FREQ=$((TOTAL_FREQ / ${#CPU_FREQS[@]}))
AVG_FREQ_GHZ=$(awk -v freq="$AVG_FREQ" 'BEGIN {printf "%.2f", freq / 1000}')

# Get min/max frequencies from cpufreq
MIN_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null)
MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
if [[ -n "$MIN_FREQ" && -n "$MAX_FREQ" ]]; then
  MIN_FREQ_GHZ=$(awk -v freq="$MIN_FREQ" 'BEGIN {printf "%.2f", freq / 1000000}')
  MAX_FREQ_GHZ=$(awk -v freq="$MAX_FREQ" 'BEGIN {printf "%.2f", freq / 1000000}')
else
  MIN_FREQ_GHZ="N/A"
  MAX_FREQ_GHZ="N/A"
fi

# Get CPU governor
CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A")

# Get CPU temperature - robust parsing for AMD Ryzen (Tctl)
CPU_TEMP=$(sensors 2>/dev/null | awk '/^Tctl:/ {print $2}' | tr -d '+°C' | head -1)
if [[ -z "$CPU_TEMP" ]]; then
  # Fallback to Tdie or other common temp sensors
  CPU_TEMP=$(sensors 2>/dev/null | awk '/^Tdie:/ {print $2}' | tr -d '+°C' | head -1)
fi
if [[ -z "$CPU_TEMP" ]]; then
  # Final fallback to Core 0
  CPU_TEMP=$(sensors 2>/dev/null | awk '/^Core 0:/ {print $3}' | tr -d '+°C' | head -1)
fi
[[ -z "$CPU_TEMP" ]] && CPU_TEMP="N/A"

# Get per-core temperatures (for AMD Ryzen with CCDs)
CORE_TEMPS=$(sensors 2>/dev/null | awk '/^Tccd[0-9]:/ {printf "%s: %s  ", $1, $2}' | sed 's/://g')

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
if [[ "$CPU_TEMP" != "N/A" ]]; then
  TEMP_INT=$(printf "%.0f" "$CPU_TEMP")
  if [[ $TEMP_INT -ge 85 ]]; then
    TEMP_COLOR="#FF0000"  # Red for critical (85°C+)
  elif [[ $TEMP_INT -ge 75 ]]; then
    TEMP_COLOR="#FFA500"  # Orange for warning (75-84°C)
  else
    TEMP_COLOR="#00FF00"  # Green for normal (<75°C)
  fi
else
  TEMP_COLOR="#FFFFFF"
fi

# Determine click action for task manager
if command -v btop &>/dev/null; then
  if command -v st &>/dev/null; then
    CLICK_CMD="st -g 140x50 -e btop"
  elif command -v alacritty &>/dev/null; then
    CLICK_CMD="alacritty -e btop"
  else
    CLICK_CMD="btop"
  fi
elif command -v htop &>/dev/null; then
  CLICK_CMD="xfce4-terminal -e htop"
elif command -v xfce4-taskmanager &>/dev/null; then
  CLICK_CMD="xfce4-taskmanager"
else
  CLICK_CMD="notify-send 'CPU Monitor' 'No task manager found'"
fi

# Panel output
if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
  INFO="<img>${ICON}</img>"
  INFO+="<txt>"
else
  INFO="<txt>"
fi

INFO+="<span color='$TEMP_COLOR'> ${CPU_TEMP}°C</span>"
INFO+="</txt>"
INFO+="<txtclick>${CLICK_CMD}</txtclick>"

# Tooltip with detailed information using FontAwesome icons
MORE_INFO="<tool>"
MORE_INFO+=" ${CPU_MODEL}\n\n"

MORE_INFO+=" Hardware\n"
MORE_INFO+="├─  Cores/Threads    ${PHYSICAL_CORES}C / ${THREADS}T\n"
MORE_INFO+="├─  Frequency        ${AVG_FREQ_GHZ} GHz (avg)\n"
MORE_INFO+="├─  Range            ${MIN_FREQ_GHZ} - ${MAX_FREQ_GHZ} GHz\n"
MORE_INFO+="└─  Governor         ${CPU_GOVERNOR}\n\n"

MORE_INFO+=" Performance\n"
MORE_INFO+="├─  CPU Usage        ${CPU_USAGE}%\n"
MORE_INFO+="├─  Temperature      ${CPU_TEMP}°C\n"
if [[ -n "$CORE_TEMPS" ]]; then
  MORE_INFO+="├─  Core Temps       ${CORE_TEMPS}\n"
fi
MORE_INFO+="└─  Load Average     ${LOAD_AVG}"

MORE_INFO+="</tool>"

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"

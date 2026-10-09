#!/usr/bin/env bash

set -euo pipefail
# Waybar GPU Module - Enhanced NVIDIA GPU monitor
# Based on XFCE gpu.sh applet

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

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
    echo '{"text":"N/A","tooltip":"NVIDIA driver not found","class":"error"}'
    exit 0
fi

# Single efficient query for all GPU metrics
GPU_METRICS="$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,power.draw,fan.speed,memory.used,memory.total,clocks.current.graphics,pstate --format=csv,noheader,nounits 2>/dev/null || true)"

if [[ -z "$GPU_METRICS" ]]; then
    echo '{"text":"Error","tooltip":"Failed to query GPU metrics","class":"error"}'
    exit 1
fi

# Parse metrics from single query
GPU_NAME="$(echo "$GPU_METRICS" | awk -F', ' '{print $1}')"
GPU_TEMP="$(echo "$GPU_METRICS" | awk -F', ' '{print $2}')"
GPU_UTIL="$(echo "$GPU_METRICS" | awk -F', ' '{print $3}')"
GPU_MEMORY="$(echo "$GPU_METRICS" | awk -F', ' '{print $4}')"
GPU_POWER="$(echo "$GPU_METRICS" | awk -F', ' '{print $5}')"
GPU_FAN_SPEED="$(echo "$GPU_METRICS" | awk -F', ' '{print $6}')"
GPU_MEM_USED="$(echo "$GPU_METRICS" | awk -F', ' '{print $7}')"
GPU_MEM_TOTAL="$(echo "$GPU_METRICS" | awk -F', ' '{print $8}')"
GPU_CLOCK="$(echo "$GPU_METRICS" | awk -F', ' '{print $9}')"
GPU_PSTATE="$(echo "$GPU_METRICS" | awk -F', ' '{print $10}')"

# Driver and CUDA version from the nvidia-smi header. This is the only second
# nvidia-smi call: the CSV query above cannot report either version, and the plain
# header form cannot report per-field metrics, so two calls is the floor. It used
# to be three, because this ran twice.
NVIDI_SMI_HEADER="$(nvidia-smi 2>/dev/null || true)"
DRIVER_VERSION="$(echo "$NVIDI_SMI_HEADER" | awk '/NVIDIA-SMI/ {print $3}' || echo "N/A")"
CUDA_VERSION="$(echo "$NVIDI_SMI_HEADER" | awk '/CUDA Version/ {print $NF}' || echo "N/A")"

# Temperature-based color coding
COLOR_NORMAL="#cdd6f4"
COLOR_LOW="#a6da95"
COLOR_MODERATE="#fe640b"
COLOR_HIGH="#e64553"
COLOR_CRITICAL="#d20f39"

# nvidia-smi reports [N/A] for a field the card or driver cannot supply, and the
# empty string for a card that has gone away. printf used to fail on the first and
# leave TEMP_INT empty, and `[[ -ge 100 ]]` then errored with "integer expression
# expected"; the comparison silently fell through to the lowest tier, so the only
# visible symptom was a line of shell noise in the journal. Accept a number or
# nothing, and keep the lowest tier the failed comparison already selected.
TEMP_INT=""
if [[ "$GPU_TEMP" =~ ^-?[0-9]+$ ]]; then
    TEMP_INT=$(printf "%.0f" "$GPU_TEMP" 2>/dev/null) || TEMP_INT=""
fi

if [[ -z "$TEMP_INT" ]]; then
    TEMP_COLOR="$COLOR_NORMAL"
    TEMP_CLASS="normal"
elif [[ $TEMP_INT -ge 100 ]]; then
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

# Emoji/Icon Selection
# EMOJI="🎮"
ICON="󰢮" # Nerd Font GPU icon

# Build display text with Pango markup
DISPLAY_TEXT="<span font_desc='JetBrainsMono Nerd Font 16' color='${TEMP_COLOR}'>${ICON}</span>  <span font_desc='JetBrainsMono Nerd Font Bold 14' color='${TEMP_COLOR}'>${GPU_TEMP}°C</span>"

# Build detailed tooltip
TOOLTIP="${ICON} ${GPU_NAME}"$'\n\n'
TOOLTIP+=" Performance"$'\n'
TOOLTIP+="├─ GPU Load: ${GPU_UTIL}%"$'\n'
TOOLTIP+="├─ Temperature: ${GPU_TEMP}°C"$'\n'
TOOLTIP+="├─ Memory: ${GPU_MEM_USED}/${GPU_MEM_TOTAL} MB (${GPU_MEMORY}%)"$'\n'
TOOLTIP+="├─ Power Draw: ${GPU_POWER} W"$'\n'
TOOLTIP+="├─ Fan Speed: ${GPU_FAN_SPEED}%"$'\n'
TOOLTIP+="├─ GPU Clock: ${GPU_CLOCK} MHz"$'\n'
TOOLTIP+="└─ Power State: ${GPU_PSTATE}"$'\n\n'

TOOLTIP+=" Drivers"$'\n'
TOOLTIP+="├─ NVIDIA: ${DRIVER_VERSION}"$'\n'
TOOLTIP+="└─ CUDA: ${CUDA_VERSION}"$'\n\n'

TOOLTIP+="󰳽 Actions"$'\n'
TOOLTIP+="└─ Click to open GPU settings"

# Output JSON for waybar
echo "{\"text\":$(wb_json_escape "${DISPLAY_TEXT}"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "${TEMP_CLASS}")}"

#!/usr/bin/env bash

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Size used for the icons is 24x24 (16x16 is also ok for a smaller panel)
readonly ICON="${DIR}/icons/gpu.png"

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
  echo "<txt>GPU: N/A</txt>"
  echo "<tool>NVIDIA driver not found</tool>"
  exit 0
fi

# Single efficient query for all GPU metrics (reduces execution time significantly)
# Query all metrics at once instead of 8+ separate nvidia-smi calls
GPU_METRICS="$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,power.draw,fan.speed,memory.used,memory.total,clocks.current.graphics,pstate --format=csv,noheader,nounits 2>/dev/null)"

if [[ -z "$GPU_METRICS" ]]; then
  echo "<txt>GPU: Error</txt>"
  echo "<tool>Failed to query GPU metrics</tool>"
  exit 1
fi

# Parse metrics from single query
readonly GPU_NAME="$(echo "$GPU_METRICS" | awk -F', ' '{print $1}')"
readonly GPU_TEMP="$(echo "$GPU_METRICS" | awk -F', ' '{print $2}')"
readonly GPU_UTIL="$(echo "$GPU_METRICS" | awk -F', ' '{print $3}')"
readonly GPU_MEMORY="$(echo "$GPU_METRICS" | awk -F', ' '{print $4}')"
readonly GPU_POWER="$(echo "$GPU_METRICS" | awk -F', ' '{print $5}')"
readonly GPU_FAN_SPEED="$(echo "$GPU_METRICS" | awk -F', ' '{print $6}')"
readonly GPU_MEM_USED="$(echo "$GPU_METRICS" | awk -F', ' '{print $7}')"
readonly GPU_MEM_TOTAL="$(echo "$GPU_METRICS" | awk -F', ' '{print $8}')"
readonly GPU_CLOCK="$(echo "$GPU_METRICS" | awk -F', ' '{print $9}')"
readonly GPU_PSTATE="$(echo "$GPU_METRICS" | awk -F', ' '{print $10}')"

# Driver and CUDA version from nvidia-smi header
readonly DRIVER_VERSION="$(nvidia-smi 2>/dev/null | awk '/NVIDIA-SMI/ {print $3}' || echo "N/A")"
readonly CUDA_VERSION="$(nvidia-smi 2>/dev/null | awk '/CUDA Version/ {print $NF}' || echo "N/A")"

# Temperature-based color coding
if [[ $GPU_TEMP -ge 80 ]]; then
  TEMP_COLOR="#FF0000"  # Red for critical (80°C+)
elif [[ $GPU_TEMP -ge 70 ]]; then
  TEMP_COLOR="#FFA500"  # Orange for warning (70-79°C)
else
  TEMP_COLOR="#00FF00"  # Green for normal (<70°C)
fi

# Determine click action based on available GPU monitoring tools
if command -v gwe &>/dev/null; then
  CLICK_CMD="gwe"
elif command -v nvidia-settings &>/dev/null; then
  CLICK_CMD="nvidia-settings"
else
  CLICK_CMD="notify-send 'GPU Monitor' 'No GPU management tool installed (gwe or nvidia-settings)'"
fi

# Panel output
if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
  INFO="<img>${ICON}</img>"
  INFO+="<txt>"
else
  INFO="<txt>"
fi

INFO+="<span color='$TEMP_COLOR'> ${GPU_TEMP}°C</span>"
INFO+="</txt>"
INFO+="<txtclick>${CLICK_CMD}</txtclick>"

# Tooltip with detailed information
MORE_INFO="<tool>"
MORE_INFO+="┌ ${GPU_NAME}\n"
MORE_INFO+="├─ GPU Load       ${GPU_UTIL}%\n"
MORE_INFO+="├─ Temperature    ${GPU_TEMP}°C\n"
MORE_INFO+="├─ Memory         ${GPU_MEM_USED}/${GPU_MEM_TOTAL} MB (${GPU_MEMORY}%)\n"
MORE_INFO+="├─ Power Draw     ${GPU_POWER} W\n"
MORE_INFO+="├─ Fan Speed      ${GPU_FAN_SPEED}%\n"
MORE_INFO+="├─ GPU Clock      ${GPU_CLOCK} MHz\n"
MORE_INFO+="└─ Power State    ${GPU_PSTATE}\n\n"

MORE_INFO+="┌ Drivers\n"
MORE_INFO+="├─ NVIDIA         ${DRIVER_VERSION}\n"
MORE_INFO+="└─ CUDA           ${CUDA_VERSION}"
MORE_INFO+="</tool>"

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"

#!/usr/bin/env bash

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Size used for the icons is 24x24 (16x16 is also ok for a smaller panel)
readonly ICON="${DIR}/icons/gpu.png"

# GPU values
readonly GPU_NAME="Radeon RX 5700 XT (Navi 10)"
#readonly GPU_TEMP="$(/opt/rocm/bin/rocm-smi -t | grep GPU | cut -c43-47)"
readonly GPU_TEMP="$(/opt/rocm/bin/rocm-smi -t | grep "Sensor edge" | cut -c42-46)"
readonly DRIVER_VERSION="$(/opt/rocm/bin/rocm-smi --showdriverversion | grep Driver | cut -c17-)"
readonly GPU_UTIL="$(/opt/rocm/bin/rocm-smi --showuse | grep "GPU use" | cut -c24-27)"
readonly GPU_MEMORY="$(/opt/rocm/bin/rocm-smi --showmemuse | grep GPU | cut -c31-)"
readonly GPU_POWER="$(/opt/rocm/bin/rocm-smi --showpower | grep Average | cut -c48-) W"
readonly GPU_FAN_SPEED="$(/opt/rocm/bin/rocm-smi -f | grep "Fan Level:" | cut -c25-)"

# Panel
if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
  INFO="<img>${ICON}</img>"
  INFO+="<txt>"
else
  INFO="<txt>"
fi
#INFO+="${GPU_UTIL}"
INFO+=" $GPU_TEMP"°C" "
INFO+="</txt>"
#    INFO+="<txtclick>gwe</txtclick>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="┌ ${GPU_NAME}\n"
MORE_INFO+="├─ GPU Load\t\t${GPU_UTIL}\n"
MORE_INFO+="├─ Temperature\t\t${GPU_TEMP}°C\n"
MORE_INFO+="├─ Memory Used\t\t${GPU_MEMORY}%\n"
MORE_INFO+="├─ Power Draw\t\t${GPU_POWER}\n"
MORE_INFO+="└─ Fan Speed\t\t${GPU_FAN_SPEED}\n\n"

MORE_INFO+="┌ Drivers\n"
MORE_INFO+="└─ AMD\t${DRIVER_VERSION}\n"
MORE_INFO+="</tool>"

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"
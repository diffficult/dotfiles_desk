#!/usr/bin/env bash
# Dependencies: bash>=3.2, coreutils, file, grep, iputils, pacman, yaourt

# Makes the script more portable
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional icon to display before the text
# Insert the absolute path of the icon
# Recommended size is 24x24 px
#readonly ICON="${DIR}/icons/package-manager/pacman.svg"
readonly ICON="${DIR}/icons/package-manager/pacman2.png"

# Calculate updates
readonly AUR=$(yay -Qua | wc -l)
readonly OFFICIAL=$(checkupdates | wc -l)
readonly ALL=$(( AUR + OFFICIAL ))

# Panel
if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
  INFO="<img>${ICON}</img>"
  INFO+="<txt>"
else
  INFO="<txt>"
  INFO+="Icon is missing!"
fi
INFO+=" ${ALL} "
INFO+="</txt>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="┌─ 📦 Updates Available\n"
MORE_INFO+="├─ ${OFFICIAL}  from repos\n"
MORE_INFO+="└─ ${AUR}  from AUR"
MORE_INFO+="</tool>"

# Panel Print
echo -e "${INFO}"

# Tooltip Print
echo -e "${MORE_INFO}"

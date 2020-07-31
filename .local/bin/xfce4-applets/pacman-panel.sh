#!/usr/bin/env bash
# Dependencies: bash>=3.2, coreutils, file, grep, iputils, pacman, yaourt

# Makes the script more portable
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional icon to display before the text
# Insert the absolute path of the icon
# Recommended size is 24x24 px
#readonly ICON="${DIR}/icons/package-manager/pacman.svg"
readonly ICON="${DIR}/icons/package-manager/pacman3.png"
readonly ICONOK="${DIR}/icons/package-manager/packageok.png"

# Calculate updates
readonly AUR=$(yay -Qua | wc -l)
readonly OFFICIAL=$(checkupdates | wc -l)
readonly ALL=$(( AUR + OFFICIAL ))

# Panel and Tooltip display
if [[ ${ALL} -eq "0" ]]; then
  if [[ $(file -b "${ICONOK}") =~ PNG|SVG ]]; then
    INFO="<img>${ICONOK}</img><click>pamac-manager</click>"
  else
  INFO="<txt>⚠️</txt>"
  fi
  MORE_INFO="<tool> ✅ Packages up to date </tool>"
else
  if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
     INFO="<img>${ICON}</img><click>pamac-manager</click><txt>"
  else
     INFO="<txt>⚠️"
  fi
  INFO+=" ${ALL} "
  INFO+="</txt>"
  MORE_INFO="<tool>"
  MORE_INFO+="┌─ ⚠️ Updates Available\n"
  MORE_INFO+="├─ ${OFFICIAL}  from repos\n"
  MORE_INFO+="└─ ${AUR}  from AUR"
  MORE_INFO+="</tool>"
fi

# Tooltip (old simple)
#MORE_INFO="<tool>"
#MORE_INFO+="┌─ 📦 Updates Available\n"
#MORE_INFO+="├─ ${OFFICIAL}  from repos\n"
#MORE_INFO+="└─ ${AUR}  from AUR"
#MORE_INFO+="</tool>"


# Panel Print
echo -e "${INFO}"


# Tooltip Print
echo -e "${MORE_INFO}"

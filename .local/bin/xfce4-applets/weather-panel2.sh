#!/usr/bin/env bash

# Weather Panel working with WTTR.IN
# type curl http://wttr.in/:help for more INFO
# try curl http://v2.wttr.in for graph chart
# or go with curl http://wttr.in/?format=3 for one liner

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Icon/Emojis
# Sunny🌣 🌞 ⛅ 🌤 🌥 ⛱
# rainy 🌦 🌧 ⛆ 🌢 ☂ ☔ 🌂 
# snowy 🌨 ☃ ⛄ ⛇ ❄ ❅ ❆
# windy 🌬 🎏 🎐
# foggy ☁ 🌫 🌁 
# stormy 🌩 ⛈ ☇ ☈
# tornado 🌪 🌀
# clear ☀ ☼ 🌞 🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘 🌙 ☾ 🌛 🌜 🌝 🌚
# 

# Weather Values

#readonly WEATHER_REPORT="$(curl --silent http://wttr.in/$1?T0F)"

readonly WEATHER_REPORT="$(curl --silent http://wttr.in/Mendoza?T0F)"
readonly WTTR_IN_PANEL="$(curl --silent http://wttr.in/Mendoza?format=3)"
readonly PANEL_ICON="$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,10,3);exit}')"
readonly CURRENT_TEMP="$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,14,4);exit}')"

# Panel
INFO="<txt> "
INFO+="${PANEL_ICON}"
INFO+=" ${CURRENT_TEMP}"
INFO+=" </txt>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="${WEATHER_REPORT}"
MORE_INFO+="</tool>"

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"



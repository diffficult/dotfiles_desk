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
# clear ☀ ☼ 🌞 🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘 🌙 ☾ 🌛 🌜 🌝 🌚 ☀️
# 

# Weather Values

#readonly WEATHER_REPORT="$(curl --silent http://wttr.in/$1?T0F)"

readonly WEATHER_REPORT="$(curl --silent http://wttr.in/Mendoza?T0F)"
readonly WTTR_IN_PANEL="$(curl --silent http://wttr.in/Mendoza?format=3)"
readonly WTTR_ICON="$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,10,2);exit}')"

# Get hour of the day
DAYNIGHT=$(date +%k)


# evaluate if it is below -0°C or above +0°C and add the "-" sign 

if [[ "$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,13,1);exit}')" == "-" ]]; then
	CURRENT_TEMP="$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,13,5);exit}')"
else
	CURRENT_TEMP="$(echo -e "${WTTR_IN_PANEL}" | awk '{print substr($0,14,5);exit}')"
fi

# evaluate if it is "clear ☀" if so, check the time of the day and use "🌛" at night

if [[ "$(echo -e "${WTTR_ICON}")" == "☀️" ]]; then
   if (( "$(echo -e "${DAYNIGHT}")" >= "19" )) || (( "$(echo -e "${DAYNIGHT}")" <= "5" )); then
	   PANEL_ICON="🌛"
   else
	   PANEL_ICON="☀️"
   fi
else
	PANEL_ICON="${WTTR_ICON}"
fi


# Panel
INFO="<txt>"
INFO+="${PANEL_ICON} "
INFO+="${CURRENT_TEMP}"
INFO+=" </txt>"
INFO+="<txtclick>st -g 126x36 -t 'Weather Report' -e sh -c 'curl wttr.in/Mendoza\?QF; read'</txtclick>"

# Tooltip
MORE_INFO="<tool>"
MORE_INFO+="${WEATHER_REPORT}"
MORE_INFO+="</tool>"

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"
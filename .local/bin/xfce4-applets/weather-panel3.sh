#!/usr/bin/env bash

# Weather Panel v3 - Enhanced version using wttr.in JSON API
# Location: Guaymallén, Mendoza, Argentina
# Features: Caching, robust parsing, detailed forecast, FontAwesome icons

# Portable directory
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
readonly LOCATION="Mendoza"  # Can also use coordinates: "-32.8833,-68.8167" for Guaymallén
readonly CACHE_FILE="${DIR}/.weather_cache.json"
readonly CACHE_DURATION=1800  # 30 minutes in seconds
readonly API_TIMEOUT=10

# Weather emoji mapping based on wttr.in weather codes
get_weather_emoji() {
    local code="$1"
    local hour=$(date +%H)

    # Determine if it's night time (20:00 - 06:00)
    local is_night=0
    if (( hour >= 20 || hour <= 6 )); then
        is_night=1
    fi

    # Weather code to emoji mapping
    case "$code" in
        113) # Clear/Sunny
            if (( is_night == 1 )); then
                echo "🌛"
            else
                echo "☀️"
            fi
            ;;
        116) echo "⛅" ;;  # Partly cloudy
        119) echo "☁️" ;;  # Cloudy
        122) echo "☁️" ;;  # Overcast
        143|248|260) echo "🌫" ;;  # Mist/Fog
        176|263|266|293|296) echo "🌦" ;;  # Light rain
        179|227|230|329|332|335|338|371|374|377) echo "🌨" ;;  # Snow
        182|185|281|284|311|314|317|350|362|365|368) echo "🌧" ;;  # Sleet/Rain
        200|386|389) echo "⛈" ;;  # Thunder
        299|302|305|308|356|359) echo "🌧" ;;  # Rain
        320|323|326) echo "❄️" ;;  # Snow
        395) echo "❄️" ;;  # Heavy snow
        392) echo "🌨" ;;  # Light snow
        *) echo "🌡" ;;  # Unknown - use thermometer
    esac
}

# Check if cache is valid
is_cache_valid() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if (( age < CACHE_DURATION )); then
        return 0
    else
        return 1
    fi
}

# Fetch weather data from wttr.in JSON API
fetch_weather() {
    if ! command -v curl &>/dev/null; then
        echo "ERROR: curl not installed"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq not installed"
        return 1
    fi

    local weather_data
    weather_data=$(curl --silent --max-time "$API_TIMEOUT" "http://wttr.in/${LOCATION}?format=j1" 2>/dev/null)

    if [[ -z "$weather_data" ]]; then
        echo "ERROR: No response from weather service"
        return 1
    fi

    # Check for error messages
    if echo "$weather_data" | grep -q "Sorry, we are running out of queries"; then
        echo "ERROR: Query limit reached"
        return 1
    fi

    if echo "$weather_data" | grep -q "Unknown location"; then
        echo "ERROR: Unknown location"
        return 1
    fi

    # Validate JSON
    if ! echo "$weather_data" | jq -e . >/dev/null 2>&1; then
        echo "ERROR: Invalid JSON response"
        return 1
    fi

    # Cache the result
    echo "$weather_data" > "$CACHE_FILE"
    echo "$weather_data"
    return 0
}

# Get weather data (from cache or fresh)
get_weather_data() {
    if is_cache_valid; then
        cat "$CACHE_FILE"
    else
        fetch_weather
    fi
}

# Main execution
weather_data=$(get_weather_data)

# Check if we got an error
if [[ "$weather_data" == ERROR:* ]]; then
    error_msg="${weather_data#ERROR: }"
    INFO="<txt>⚠️</txt>"
    MORE_INFO="<tool>⚠️ ${error_msg} ⚠️</tool>"
    echo -e "${INFO}"
    echo -e "${MORE_INFO}"
    exit 0
fi

# Parse weather data using jq
if command -v jq &>/dev/null && [[ -n "$weather_data" ]]; then
    # Current conditions
    TEMP_C=$(echo "$weather_data" | jq -r '.current_condition[0].temp_C // "N/A"')
    FEELS_LIKE_C=$(echo "$weather_data" | jq -r '.current_condition[0].FeelsLikeC // "N/A"')
    WEATHER_DESC=$(echo "$weather_data" | jq -r '.current_condition[0].weatherDesc[0].value // "Unknown"')
    WEATHER_CODE=$(echo "$weather_data" | jq -r '.current_condition[0].weatherCode // "0"')
    HUMIDITY=$(echo "$weather_data" | jq -r '.current_condition[0].humidity // "N/A"')
    WIND_SPEED=$(echo "$weather_data" | jq -r '.current_condition[0].windspeedKmph // "N/A"')
    WIND_DIR=$(echo "$weather_data" | jq -r '.current_condition[0].winddir16Point // "N/A"')
    PRESSURE=$(echo "$weather_data" | jq -r '.current_condition[0].pressure // "N/A"')
    UV_INDEX=$(echo "$weather_data" | jq -r '.current_condition[0].uvIndex // "N/A"')
    VISIBILITY=$(echo "$weather_data" | jq -r '.current_condition[0].visibility // "N/A"')
    CLOUD_COVER=$(echo "$weather_data" | jq -r '.current_condition[0].cloudcover // "N/A"')
    PRECIP_MM=$(echo "$weather_data" | jq -r '.current_condition[0].precipMM // "N/A"')

    # Location info
    AREA_NAME=$(echo "$weather_data" | jq -r '.nearest_area[0].areaName[0].value // "Unknown"')
    COUNTRY=$(echo "$weather_data" | jq -r '.nearest_area[0].country[0].value // "Unknown"')

    # Get weather emoji
    WEATHER_EMOJI=$(get_weather_emoji "$WEATHER_CODE")

    # Build panel display
    if [[ "$TEMP_C" != "N/A" ]]; then
        TEMP_DISPLAY="+${TEMP_C}°C"
    else
        TEMP_DISPLAY="N/A"
    fi

    # Determine terminal for click action
    if command -v st &>/dev/null; then
        TERM_CMD="st -g 126x36 -t 'Weather Report' -e"
    elif command -v alacritty &>/dev/null; then
        TERM_CMD="alacritty -t 'Weather Report' -e"
    elif command -v xfce4-terminal &>/dev/null; then
        TERM_CMD="xfce4-terminal -T 'Weather Report' -e"
    else
        TERM_CMD="sh -c"
    fi

    # Panel output
    INFO="<txt>"
    INFO+="${WEATHER_EMOJI} ${TEMP_DISPLAY}"
    INFO+="</txt>"
    INFO+="<txtclick>${TERM_CMD} sh -c 'curl wttr.in/${LOCATION}?QF ; read'</txtclick>"

    # Build detailed tooltip with FontAwesome icons
    MORE_INFO="<tool>"
    MORE_INFO+=" ${AREA_NAME}, ${COUNTRY}\n"
    MORE_INFO+="${WEATHER_EMOJI} ${WEATHER_DESC}\n\n"

    MORE_INFO+=" Current Conditions\n"
    MORE_INFO+="├─  Temperature      ${TEMP_C}°C (feels like ${FEELS_LIKE_C}°C)\n"
    MORE_INFO+="├─  Humidity         ${HUMIDITY}%\n"
    MORE_INFO+="├─  Wind             ${WIND_SPEED} km/h ${WIND_DIR}\n"
    MORE_INFO+="├─  Pressure         ${PRESSURE} hPa\n"
    MORE_INFO+="├─  Cloud Cover      ${CLOUD_COVER}%\n"
    MORE_INFO+="├─  Visibility       ${VISIBILITY} km\n"
    MORE_INFO+="├─  UV Index         ${UV_INDEX}\n"
    MORE_INFO+="└─  Precipitation    ${PRECIP_MM} mm\n\n"

    # Add 3-day forecast
    MORE_INFO+=" 3-Day Forecast\n"
    for i in 0 1 2; do
        DAY_DATE=$(echo "$weather_data" | jq -r ".weather[$i].date // \"N/A\"")
        DAY_MAX=$(echo "$weather_data" | jq -r ".weather[$i].maxtempC // \"N/A\"")
        DAY_MIN=$(echo "$weather_data" | jq -r ".weather[$i].mintempC // \"N/A\"")
        DAY_DESC=$(echo "$weather_data" | jq -r ".weather[$i].hourly[4].weatherDesc[0].value // \"Unknown\"")
        DAY_CODE=$(echo "$weather_data" | jq -r ".weather[$i].hourly[4].weatherCode // \"0\"")
        DAY_EMOJI=$(get_weather_emoji "$DAY_CODE")

        # Format date nicely
        if [[ "$DAY_DATE" != "N/A" ]]; then
            DAY_NAME=$(date -d "$DAY_DATE" "+%a %b %d" 2>/dev/null || echo "$DAY_DATE")
        else
            DAY_NAME="N/A"
        fi

        if (( i == 2 )); then
            MORE_INFO+="└─ ${DAY_NAME}: ${DAY_EMOJI} ${DAY_MIN}°C - ${DAY_MAX}°C  ${DAY_DESC}"
        else
            MORE_INFO+="├─ ${DAY_NAME}: ${DAY_EMOJI} ${DAY_MIN}°C - ${DAY_MAX}°C  ${DAY_DESC}\n"
        fi
    done

    MORE_INFO+="</tool>"

else
    # Fallback if jq is not available or data is invalid
    INFO="<txt>⚠️</txt>"
    MORE_INFO="<tool>⚠️ Unable to parse weather data. Install jq for full functionality. ⚠️</tool>"
fi

# Output panel
echo -e "${INFO}"

# Output hover menu
echo -e "${MORE_INFO}"

#!/usr/bin/env bash
# Pacman Panel v3 - Enhanced Arch Linux update monitor
# Dependencies: bash>=4.0, coreutils, file, pacman-contrib (checkupdates), yay
# Features: Caching, performance optimization, detailed package info, FontAwesome icons

# Makes the script more portable
readonly DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
readonly ICON="${DIR}/icons/package-manager/pacman51.png"
readonly ICONOK="${DIR}/icons/package-manager/packageok11.png"
readonly CACHE_DIR="${DIR}/.cache"
readonly CACHE_FILE="${CACHE_DIR}/pacman_updates.cache"
readonly CACHE_DURATION=3600  # 1 hour in seconds
readonly CHECK_TIMEOUT=120     # 2 minutes max for update check

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Critical packages to highlight (system-critical updates)
readonly CRITICAL_PACKAGES=(
    "linux" "linux-lts" "linux-zen" "linux-hardened"
    "nvidia" "nvidia-dkms" "nvidia-lts" "nvidia-open" "nvidia-open-dkms"
    "mesa" "lib32-mesa"
    "systemd" "lib32-systemd"
    "glibc" "lib32-glibc"
    "gcc" "gcc-libs" "lib32-gcc-libs"
    "kernel" "xorg-server"
)

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

# Get cache age in human-readable format
get_cache_age() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        echo "Never"
        return
    fi

    local cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if (( age < 60 )); then
        echo "${age}s ago"
    elif (( age < 3600 )); then
        echo "$((age / 60))m ago"
    else
        echo "$((age / 3600))h ago"
    fi
}

# Fetch updates and cache results
fetch_updates() {
    local temp_file="${CACHE_FILE}.tmp"

    # Check if required commands exist
    if ! command -v checkupdates &>/dev/null; then
        echo "ERROR:checkupdates not found. Install pacman-contrib."
        return 1
    fi

    if ! command -v yay &>/dev/null; then
        echo "ERROR:yay not found. Install yay AUR helper."
        return 1
    fi

    # Fetch official repo updates (with timeout)
    local official_updates
    official_updates=$(timeout "$CHECK_TIMEOUT" checkupdates 2>/dev/null || echo "")

    # Fetch AUR updates (with timeout)
    local aur_updates
    aur_updates=$(timeout "$CHECK_TIMEOUT" yay -Qua 2>/dev/null || echo "")

    # Save to temp cache file
    {
        echo "TIMESTAMP=$(date +%s)"
        echo "OFFICIAL_UPDATES_START"
        echo "$official_updates"
        echo "OFFICIAL_UPDATES_END"
        echo "AUR_UPDATES_START"
        echo "$aur_updates"
        echo "AUR_UPDATES_END"
    } > "$temp_file"

    # Move temp file to actual cache (atomic operation)
    mv "$temp_file" "$CACHE_FILE"

    echo "$CACHE_FILE"
}

# Parse cached data
parse_cache() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    # Extract official updates
    OFFICIAL_LIST=$(sed -n '/OFFICIAL_UPDATES_START/,/OFFICIAL_UPDATES_END/p' "$CACHE_FILE" | \
                    grep -v "OFFICIAL_UPDATES_START\|OFFICIAL_UPDATES_END")

    # Extract AUR updates
    AUR_LIST=$(sed -n '/AUR_UPDATES_START/,/AUR_UPDATES_END/p' "$CACHE_FILE" | \
               grep -v "AUR_UPDATES_START\|AUR_UPDATES_END")
}

# Count packages matching pattern
count_packages() {
    local package_list="$1"
    local pattern="$2"

    if [[ -z "$package_list" ]]; then
        echo 0
        return
    fi

    echo "$package_list" | grep -E "$pattern" | wc -l
}

# Get top N packages from list
get_top_packages() {
    local package_list="$1"
    local count="$2"

    if [[ -z "$package_list" ]]; then
        return
    fi

    echo "$package_list" | head -n "$count" | awk '{print $1}'
}

# Main execution
if is_cache_valid; then
    # Use cached data
    parse_cache
else
    # Fetch fresh data
    result=$(fetch_updates)
    if [[ "$result" == ERROR:* ]]; then
        error_msg="${result#ERROR:}"
        INFO="<txt>⚠️</txt>"
        MORE_INFO="<tool>⚠️ ${error_msg} ⚠️</tool>"
        echo -e "${INFO}"
        echo -e "${MORE_INFO}"
        exit 0
    fi
    parse_cache
fi

# Calculate update counts
OFFICIAL_COUNT=$(echo "$OFFICIAL_LIST" | grep -c "^[a-zA-Z0-9]" || echo 0)
AUR_COUNT=$(echo "$AUR_LIST" | grep -c "^[a-zA-Z0-9]" || echo 0)
ALL_COUNT=$((OFFICIAL_COUNT + AUR_COUNT))

# Check for critical package updates
KERNEL_COUNT=$(count_packages "$OFFICIAL_LIST" '^(linux|linux-lts|linux-zen|linux-hardened)( |$)')
AUR_KERNEL_COUNT=$(count_packages "$AUR_LIST" '^(linux|linux-lts|linux-zen|linux-hardened)( |$)')
TOTAL_KERNEL=$((KERNEL_COUNT + AUR_KERNEL_COUNT))

NVIDIA_COUNT=$(count_packages "$OFFICIAL_LIST" '^nvidia')
AUR_NVIDIA_COUNT=$(count_packages "$AUR_LIST" '^nvidia')
TOTAL_NVIDIA=$((NVIDIA_COUNT + AUR_NVIDIA_COUNT))

MESA_COUNT=$(count_packages "$OFFICIAL_LIST" '^(mesa|lib32-mesa)( |$)')
SYSTEMD_COUNT=$(count_packages "$OFFICIAL_LIST" '^(systemd|lib32-systemd)( |$)')
GLIBC_COUNT=$(count_packages "$OFFICIAL_LIST" '^(glibc|lib32-glibc)( |$)')

# Determine terminal for update command
if command -v st &>/dev/null; then
    TERM_CMD="st -g 140x50 -t 'System Update' -e"
elif command -v alacritty &>/dev/null; then
    TERM_CMD="alacritty -t 'System Update' -e"
elif command -v xfce4-terminal &>/dev/null; then
    TERM_CMD="xfce4-terminal -T 'System Update' -e"
else
    TERM_CMD="xterm -T 'System Update' -e"
fi

# Build panel and tooltip
if [[ $ALL_COUNT -eq 0 ]]; then
    # No updates available
    if [[ $(file -b "${ICONOK}") =~ PNG|SVG ]]; then
        INFO="<img>${ICONOK}</img>"
    else
        INFO="<txt>✅</txt>"
    fi

    # Add click to force refresh
    INFO+="<click>${TERM_CMD} sh -c 'echo Checking for updates...; rm -f ${CACHE_FILE}; bash ${DIR}/$(basename "$0"); echo; echo Press Enter to close; read'</click>"

    CACHE_AGE=$(get_cache_age)
    MORE_INFO="<tool>✅ <span weight='Bold'>System Up to Date</span>\n\n"
    MORE_INFO+=" Last Check\n"
    MORE_INFO+="├─ ${CACHE_AGE}\n\n"
    MORE_INFO+=" Actions\n"
    MORE_INFO+="└─ Click icon to force refresh"
    MORE_INFO+="</tool>"

else
    # Updates available
    if [[ $(file -b "${ICON}") =~ PNG|SVG ]]; then
        INFO="<img>${ICON}</img>"
    else
        INFO="<txt>📦</txt>"
    fi

    # Add click to open GNOME Software
    if command -v gnome-software &>/dev/null; then
        INFO+="<click>gnome-software %U</click>"
    fi

    INFO+="<txt> ${ALL_COUNT}</txt>"
    INFO+="<txtclick>${TERM_CMD} sh -c 'yay; echo; echo Update complete. Press Enter to close; read; rm -f ${CACHE_FILE}'</txtclick>"

    # Build detailed tooltip with FontAwesome icons
    MORE_INFO="<tool>📦 <span weight='Bold' fgcolor='#FFA500'>Updates Available: ${ALL_COUNT}</span>\n\n"

    # Summary section
    MORE_INFO+=" 📊 Package Summary\n"
    MORE_INFO+="├─  Official Repos    <span weight='Bold'>${OFFICIAL_COUNT}</span>\n"
    MORE_INFO+="└─  AUR              <span weight='Bold'>${AUR_COUNT}</span>\n\n"

    # Critical updates section
    critical_found=0

    if [[ $TOTAL_KERNEL -gt 0 || $TOTAL_NVIDIA -gt 0 || $MESA_COUNT -gt 0 || $SYSTEMD_COUNT -gt 0 || $GLIBC_COUNT -gt 0 ]]; then
        MORE_INFO+="⚠️  <span weight='Bold' fgcolor='#FF4500'>Critical Updates</span>\n"

        # Count how many critical items we have
        critical_items=0
        [[ $TOTAL_KERNEL -gt 0 ]] && ((critical_items++))
        [[ $TOTAL_NVIDIA -gt 0 ]] && ((critical_items++))
        [[ $MESA_COUNT -gt 0 ]] && ((critical_items++))
        [[ $SYSTEMD_COUNT -gt 0 ]] && ((critical_items++))
        [[ $GLIBC_COUNT -gt 0 ]] && ((critical_items++))

        current_item=0

        if [[ $TOTAL_KERNEL -gt 0 ]]; then
            ((current_item++))
            if [[ $current_item -eq $critical_items ]]; then
                MORE_INFO+="└─ 🐧 Kernel           <span weight='Bold' fgcolor='#FF8C00'>${TOTAL_KERNEL}</span>\n"
            else
                MORE_INFO+="├─ 🐧 Kernel           <span weight='Bold' fgcolor='#FF8C00'>${TOTAL_KERNEL}</span>\n"
            fi
            critical_found=1
        fi

        if [[ $TOTAL_NVIDIA -gt 0 ]]; then
            ((current_item++))
            if [[ $current_item -eq $critical_items ]]; then
                MORE_INFO+="└─ 🎮 NVIDIA           <span weight='Bold' fgcolor='#76B900'>${TOTAL_NVIDIA}</span>\n"
            else
                MORE_INFO+="├─ 🎮 NVIDIA           <span weight='Bold' fgcolor='#76B900'>${TOTAL_NVIDIA}</span>\n"
            fi
            critical_found=1
        fi

        if [[ $MESA_COUNT -gt 0 ]]; then
            ((current_item++))
            if [[ $current_item -eq $critical_items ]]; then
                MORE_INFO+="└─  Mesa             <span weight='Bold' fgcolor='#FF8C00'>${MESA_COUNT}</span>\n"
            else
                MORE_INFO+="├─  Mesa             <span weight='Bold' fgcolor='#FF8C00'>${MESA_COUNT}</span>\n"
            fi
            critical_found=1
        fi

        if [[ $SYSTEMD_COUNT -gt 0 ]]; then
            ((current_item++))
            if [[ $current_item -eq $critical_items ]]; then
                MORE_INFO+="└─  systemd          <span weight='Bold' fgcolor='#FF4500'>${SYSTEMD_COUNT}</span>\n"
            else
                MORE_INFO+="├─  systemd          <span weight='Bold' fgcolor='#FF4500'>${SYSTEMD_COUNT}</span>\n"
            fi
            critical_found=1
        fi

        if [[ $GLIBC_COUNT -gt 0 ]]; then
            ((current_item++))
            MORE_INFO+="└─  glibc            <span weight='Bold' fgcolor='#FF4500'>${GLIBC_COUNT}</span>\n"
            critical_found=1
        fi

        MORE_INFO+="\n"
    fi

    # Show top packages (max 8)
    if [[ $OFFICIAL_COUNT -gt 0 ]]; then
        MORE_INFO+=" 📥 Top Official Packages\n"
        top_official=$(get_top_packages "$OFFICIAL_LIST" 5)
        count=0
        total_lines=$(echo "$top_official" | wc -l)
        while IFS= read -r pkg; do
            ((count++))
            if [[ $count -eq $total_lines ]]; then
                MORE_INFO+="└─ ${pkg}\n"
            else
                MORE_INFO+="├─ ${pkg}\n"
            fi
        done <<< "$top_official"

        if [[ $OFFICIAL_COUNT -gt 5 ]]; then
            MORE_INFO+="   💭 ... and $((OFFICIAL_COUNT - 5)) more\n"
        fi
        MORE_INFO+="\n"
    fi

    if [[ $AUR_COUNT -gt 0 ]]; then
        MORE_INFO+=" 🔧 Top AUR Packages\n"
        top_aur=$(get_top_packages "$AUR_LIST" 3)
        count=0
        total_lines=$(echo "$top_aur" | wc -l)
        while IFS= read -r pkg; do
            ((count++))
            if [[ $count -eq $total_lines ]]; then
                MORE_INFO+="└─ ${pkg}\n"
            else
                MORE_INFO+="├─ ${pkg}\n"
            fi
        done <<< "$top_aur"

        if [[ $AUR_COUNT -gt 3 ]]; then
            MORE_INFO+="   💭 ... and $((AUR_COUNT - 3)) more\n"
        fi
        MORE_INFO+="\n"
    fi

    # Footer with actions
    CACHE_AGE=$(get_cache_age)
    MORE_INFO+="ℹ️  <span weight='Bold'>Information</span>\n"
    MORE_INFO+="└─ Last check: ${CACHE_AGE}\n\n"
    MORE_INFO+=" 🖱️  Actions\n"
    MORE_INFO+="├─ Click icon → Software Center\n"
    MORE_INFO+="└─ Click text → Terminal Update"

    MORE_INFO+="</tool>"
fi

# Output panel
echo -e "${INFO}"

# Output tooltip
echo -e "${MORE_INFO}"

#!/usr/bin/env bash

set -euo pipefail
# Waybar Pacman Module - Enhanced Arch Linux update monitor
# Based on pacman-panel3.sh with waybar JSON output
# Dependencies: bash>=4.0, coreutils, pacman-contrib (checkupdates), yay

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

# Configuration
readonly CACHE_DIR="${HOME}/.cache/waybar"
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
        echo '{"text":"⚠️","tooltip":"checkupdates not found. Install pacman-contrib.","class":"error"}'
        exit 0
    fi

    if ! command -v yay &>/dev/null; then
        echo '{"text":"⚠️","tooltip":"yay not found. Install yay AUR helper.","class":"error"}'
        exit 0
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
}

# Parse cached data
parse_cache() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    # Extract official updates. `grep -v` exits 1 when it filters away every line,
    # which is what an empty update list looks like, so it needs to be tolerated
    # or errexit kills the script on the very case that is supposed to render
    # "System Up to Date".
    OFFICIAL_LIST=$(sed -n '/OFFICIAL_UPDATES_START/,/OFFICIAL_UPDATES_END/p' "$CACHE_FILE" | \
                    grep -v "OFFICIAL_UPDATES_START\|OFFICIAL_UPDATES_END" || true)

    # Extract AUR updates
    AUR_LIST=$(sed -n '/AUR_UPDATES_START/,/AUR_UPDATES_END/p' "$CACHE_FILE" | \
               grep -v "AUR_UPDATES_START\|AUR_UPDATES_END" || true)
}

# Count packages matching pattern
count_packages() {
    local package_list="$1"
    local pattern="$2"

    if [[ -z "$package_list" ]]; then
        echo 0
        return
    fi

    # The `|| true` is for errexit + pipefail, not for the count. With pipefail the
    # pipeline takes grep's status, and grep exits 1 when the pattern does not
    # match -- which is the ordinary answer here (most refreshes have no AUR kernel
    # update, no nvidia update, ...). wc has already printed the correct 0 by then.
    echo "$package_list" | grep -E "$pattern" | wc -l || true
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
    fetch_updates
    parse_cache
fi

# Calculate update counts
OFFICIAL_COUNT=0
AUR_COUNT=0
if [[ -n "$OFFICIAL_LIST" ]]; then
    OFFICIAL_COUNT=$(echo "$OFFICIAL_LIST" | grep -c "^[a-zA-Z0-9]" || true)
fi
if [[ -n "$AUR_LIST" ]]; then
    AUR_COUNT=$(echo "$AUR_LIST" | grep -c "^[a-zA-Z0-9]" || true)
fi
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

CACHE_AGE=$(get_cache_age)

# Build output based on update count
if [[ $ALL_COUNT -eq 0 ]]; then
    # No updates available
    TOOLTIP="  System Up to Date"$'\n\n'
    TOOLTIP+="Last Check: ${CACHE_AGE}"$'\n\n'
    TOOLTIP+="Actions:"$'\n'
    TOOLTIP+="• Click to force refresh"

    echo "{\"text\":$(wb_json_escape "<span font='JetBrainsMono Nerd Font 14'> </span>"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "up-to-date")}"
else
    # Updates available
    TOOLTIP="📦 Updates Available: ${ALL_COUNT}"$'\n\n'

    # Summary section
    TOOLTIP+="📊 Package Summary"$'\n'
    TOOLTIP+="├─ Official Repos: ${OFFICIAL_COUNT}"$'\n'
    TOOLTIP+="└─ AUR: ${AUR_COUNT}"$'\n\n'

    # Critical updates section
    if [[ $TOTAL_KERNEL -gt 0 || $TOTAL_NVIDIA -gt 0 || $MESA_COUNT -gt 0 || $SYSTEMD_COUNT -gt 0 || $GLIBC_COUNT -gt 0 ]]; then
        TOOLTIP+="⚠️ Critical Updates"$'\n'

        # The five `[[ ... ]] && ((x++))` lines this used to be. Two problems: the
        # list's exit status is the last test's, so a false test on the last line
        # made the whole block look like a failure; and `((x++))` returns 1 while x
        # is 0, because the value of the expression is the pre-increment one. Under
        # errexit the block would abort on the first critical package found and
        # print nothing at all. `x=$((x + 1))` is an assignment, so it always
        # succeeds, and the counting is identical.
        critical_items=0
        if [[ $TOTAL_KERNEL -gt 0 ]]; then critical_items=$((critical_items + 1)); fi
        if [[ $TOTAL_NVIDIA -gt 0 ]]; then critical_items=$((critical_items + 1)); fi
        if [[ $MESA_COUNT -gt 0 ]]; then critical_items=$((critical_items + 1)); fi
        if [[ $SYSTEMD_COUNT -gt 0 ]]; then critical_items=$((critical_items + 1)); fi
        if [[ $GLIBC_COUNT -gt 0 ]]; then critical_items=$((critical_items + 1)); fi

        current_item=0

        if [[ $TOTAL_KERNEL -gt 0 ]]; then
            current_item=$((current_item + 1))
            if [[ $current_item -eq $critical_items ]]; then
                TOOLTIP+="└─ 🐧 Kernel: ${TOTAL_KERNEL}"$'\n'
            else
                TOOLTIP+="├─ 🐧 Kernel: ${TOTAL_KERNEL}"$'\n'
            fi
        fi

        if [[ $TOTAL_NVIDIA -gt 0 ]]; then
            current_item=$((current_item + 1))
            if [[ $current_item -eq $critical_items ]]; then
                TOOLTIP+="└─ 🎮 NVIDIA: ${TOTAL_NVIDIA}"$'\n'
            else
                TOOLTIP+="├─ 🎮 NVIDIA: ${TOTAL_NVIDIA}"$'\n'
            fi
        fi

        if [[ $MESA_COUNT -gt 0 ]]; then
            current_item=$((current_item + 1))
            if [[ $current_item -eq $critical_items ]]; then
                TOOLTIP+="└─ Mesa: ${MESA_COUNT}"$'\n'
            else
                TOOLTIP+="├─ Mesa: ${MESA_COUNT}"$'\n'
            fi
        fi

        if [[ $SYSTEMD_COUNT -gt 0 ]]; then
            current_item=$((current_item + 1))
            if [[ $current_item -eq $critical_items ]]; then
                TOOLTIP+="└─ systemd: ${SYSTEMD_COUNT}"$'\n'
            else
                TOOLTIP+="├─ systemd: ${SYSTEMD_COUNT}"$'\n'
            fi
        fi

        if [[ $GLIBC_COUNT -gt 0 ]]; then
            current_item=$((current_item + 1))
            TOOLTIP+="└─ glibc: ${GLIBC_COUNT}"$'\n'
        fi

        TOOLTIP+=$'\n'
    fi

    # Show top packages (max 5 official, 3 AUR)
    if [[ $OFFICIAL_COUNT -gt 0 ]]; then
        TOOLTIP+="📥 Top Official Packages"$'\n'
        top_official=$(get_top_packages "$OFFICIAL_LIST" 5)
        count=0
        total_lines=$(echo "$top_official" | wc -l)
        while IFS= read -r pkg; do
            count=$((count + 1))
            if [[ $count -eq $total_lines ]]; then
                TOOLTIP+="└─ ${pkg}"$'\n'
            else
                TOOLTIP+="├─ ${pkg}"$'\n'
            fi
        done <<< "$top_official"

        if [[ $OFFICIAL_COUNT -gt 5 ]]; then
            TOOLTIP+="   ... and $((OFFICIAL_COUNT - 5)) more"$'\n'
        fi
        TOOLTIP+=$'\n'
    fi

    if [[ $AUR_COUNT -gt 0 ]]; then
        TOOLTIP+="🔧 Top AUR Packages"$'\n'
        top_aur=$(get_top_packages "$AUR_LIST" 3)
        count=0
        total_lines=$(echo "$top_aur" | wc -l)
        while IFS= read -r pkg; do
            count=$((count + 1))
            if [[ $count -eq $total_lines ]]; then
                TOOLTIP+="└─ ${pkg}"$'\n'
            else
                TOOLTIP+="├─ ${pkg}"$'\n'
            fi
        done <<< "$top_aur"

        if [[ $AUR_COUNT -gt 3 ]]; then
            TOOLTIP+="   ... and $((AUR_COUNT - 3)) more"$'\n'
        fi
        TOOLTIP+=$'\n'
    fi

    # Footer with actions
    TOOLTIP+="ℹ️ Information"$'\n'
    TOOLTIP+="└─ Last check: ${CACHE_AGE}"$'\n\n'
    TOOLTIP+="🖱️ Actions"$'\n'
    TOOLTIP+="├─ Left click: Software Center"$'\n'
    TOOLTIP+="└─ Right click: Terminal Update"

    echo "{\"text\":$(wb_json_escape "<span font='JetBrainsMono Nerd Font Bold 14'>📦 ${ALL_COUNT}</span>"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "updates-available")}"
fi

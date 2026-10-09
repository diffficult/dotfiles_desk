#!/usr/bin/env bash

set -euo pipefail
# Waybar Network Module - Enhanced network monitor with usage graph
# Based on XFCE network.sh applet

# `ip` is load-bearing: every reading below comes out of it, so without iproute2
# the old script just took the "no default route" branch and claimed the machine
# had no network. Say which tool is missing instead.

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

if ! command -v ip &>/dev/null; then
    echo '{"text":"N/A","tooltip":"iproute2 not installed","class":"error"}'
    exit 0
fi

# Not guarded, and deliberately so: awk, sed, cat, date, sort, cut, tail and stat
# are the POSIX base set. A `command -v` check for a tool whose absence would
# already have broken the shell four lines earlier buys nothing.

# Get network interface (prefer wired over wireless)
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -1)
if [[ -z "$INTERFACE" ]]; then
    echo '{"text":"No Network","tooltip":"No active network interface","class":"disconnected"}'
    exit 0
fi

# Persistent state (history + caches). Namespaced per user and per script so two
# users on one machine -- and the network.sh / network2.sh variants, which used to
# share one fixed /tmp path -- never interleave two writers on one file.
WARMIND_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/warmind/waybar"
mkdir -p "$WARMIND_STATE_DIR"

# One-time migration of the old un-namespaced /tmp state. Idempotent: it copies
# only while the new file is still absent, so the seeding happens exactly once.
# The old /tmp file is deliberately left in place, not deleted: the user may want
# it back, and deleting a shared /tmp file is not ours to do.
migrate_legacy_state() {
    local legacy_file="$1" current_file="$2"
    if [[ -f "$legacy_file" && ! -f "$current_file" ]]; then
        cp "$legacy_file" "$current_file" 2>/dev/null || true
    fi
}

# Get network type and name
if [[ "$INTERFACE" =~ ^(eth|enp|eno) ]]; then
    NETWORK_TYPE="ethernet"
    NETWORK_NAME="$INTERFACE"
elif [[ "$INTERFACE" =~ ^(wlan|wlp) ]]; then
    NETWORK_TYPE="wifi"
    NETWORK_NAME=$(iwgetid -r 2>/dev/null || echo "$INTERFACE")
else
    NETWORK_TYPE="unknown"
    NETWORK_NAME="$INTERFACE"
fi

# Check for VPN connection. The anchor keeps the match on the interface name field
# ("12: tun0@NONE: <...>"); the previous unanchored "(tun|tap|wg|ppp)" matched any
# line of `ip link show`, so it also fired on an altname, alias, master name or
# `link/...` type field that merely contained those letters.
VPN_ACTIVE=false
if ip link show | grep -qE "^[[:space:]]*[0-9]+:[[:space:]]+(tun|tap|wg|ppp)[0-9]*(@[^:]*)?:"; then
    VPN_ACTIVE=true
fi

# A VPN/online/no-internet STATUS_COLOR/STATUS_TEXT block used to sit here, along
# with a `ping 8.8.8.8` connectivity probe. It was dead code and has been removed:
#   * it tested $LINK_STATUS, which is not assigned until the "Check link status"
#     block further down, so the condition always compared against the empty string;
#   * whichever colour it picked was unconditionally overwritten by that later block
#     before DISPLAY_TEXT was built, so nothing it computed ever reached stdout;
#   * the same `ping 8.8.8.8` also ran in the WAYBAR_CLASS block, so a live bar paid
#     for two identical connectivity probes on every refresh.
# The live colouring is the "Check link status" block below, whose ping is now the
# only connectivity probe. Do not re-add the removed block here: it cannot work,
# because LINK_STATUS is still unset at this point in the script.

ICON=" "

# Get current RX/TX bytes
RX_BYTES=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes 2>/dev/null || echo 0)
TX_BYTES=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes 2>/dev/null || echo 0)

# History file for network usage
HISTORY_FILE="${WARMIND_STATE_DIR}/network_history"
migrate_legacy_state "/tmp/waybar_network_history" "$HISTORY_FILE"
CURRENT_TIME=$(date +%s)

# Read previous values if they exist
if [[ -f "$HISTORY_FILE" ]]; then
    PREV_DATA=$(cat "$HISTORY_FILE")
    PREV_TIME=$(echo "$PREV_DATA" | cut -d' ' -f1)
    PREV_RX=$(echo "$PREV_DATA" | cut -d' ' -f2)
    PREV_TX=$(echo "$PREV_DATA" | cut -d' ' -f3)

    # Calculate time difference and rates
    TIME_DIFF=$((CURRENT_TIME - PREV_TIME))
    if [[ $TIME_DIFF -gt 0 ]]; then
        RX_RATE=$(( (RX_BYTES - PREV_RX) / TIME_DIFF ))
        TX_RATE=$(( (TX_BYTES - PREV_TX) / TIME_DIFF ))

        # Convert to human readable
        RX_RATE_HUMAN=$(numfmt --to=iec-i --suffix=B/s "$RX_RATE" 2>/dev/null || echo "${RX_RATE} B/s")
        TX_RATE_HUMAN=$(numfmt --to=iec-i --suffix=B/s "$TX_RATE" 2>/dev/null || echo "${TX_RATE} B/s")
    else
        RX_RATE_HUMAN="0 B/s"
        TX_RATE_HUMAN="0 B/s"
    fi
else
    RX_RATE_HUMAN="0 B/s"
    TX_RATE_HUMAN="0 B/s"
fi

# RX_RATE/TX_RATE are read after this point whether or not the rate block above
# ran, and an unset variable under `set -u` is fatal. They default to the zero
# the graph path already handled.
RX_RATE=0
TX_RATE=0

# Save current values for next run
echo "$CURRENT_TIME $RX_BYTES $TX_BYTES" > "$HISTORY_FILE"

# Network usage graph (track download rate history)
GRAPH_HISTORY_FILE="${WARMIND_STATE_DIR}/network_graph"
migrate_legacy_state "/tmp/waybar_network_graph" "$GRAPH_HISTORY_FILE"
echo "$RX_RATE" >> "$GRAPH_HISTORY_FILE"
tail -8 "$GRAPH_HISTORY_FILE" > "${GRAPH_HISTORY_FILE}.tmp" && mv "${GRAPH_HISTORY_FILE}.tmp" "$GRAPH_HISTORY_FILE"

# Generate mini bar graph
if [[ -f "$GRAPH_HISTORY_FILE" ]]; then
    # Find max value for scaling
    MAX_RATE=$(sort -n "$GRAPH_HISTORY_FILE" | tail -1)
    if [[ "$MAX_RATE" -gt 0 ]]; then
        GRAPH=""
        while read -r rate; do
            # Scale to 0-7 based on max rate
            height=$(awk -v v="$rate" -v max="$MAX_RATE" 'BEGIN {printf "%.0f", (v/max)*7}')
            case $height in
                0) GRAPH+="▁" ;;
                1) GRAPH+="▂" ;;
                2) GRAPH+="▃" ;;
                3) GRAPH+="▄" ;;
                4) GRAPH+="▅" ;;
                5) GRAPH+="▆" ;;
                6) GRAPH+="▇" ;;
                7) GRAPH+="█" ;;
            esac
        done < "$GRAPH_HISTORY_FILE"
        NETWORK_GRAPH=" $GRAPH"
    else
        NETWORK_GRAPH=""
    fi
else
    NETWORK_GRAPH=""
fi

# Get IP address and link status
IP_ADDR=$(ip addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d'/' -f1 | head -1)
if [[ -z "$IP_ADDR" ]]; then
    IP_ADDR="No IP"
fi

# Get NetworkManager connection name. nmcli is optional infrastructure, not a
# hard dependency: without it the tooltip used to say "Unknown" and gave the user
# no way to tell "no connection" from "no NetworkManager". Name the missing tool.
if command -v nmcli &>/dev/null; then
    CONNECTION_NAME=$(nmcli -t -f NAME connection show --active | grep -v "lo\|docker\|virbr\|br-" | head -1)
else
    CONNECTION_NAME="Unknown (nmcli not installed)"
fi
if [[ -z "$CONNECTION_NAME" ]]; then
    CONNECTION_NAME="Unknown"
fi

# Check link status
LINK_STATUS=$(ip link show "$INTERFACE" | awk '/state/ {print $9}')
if [[ "$LINK_STATUS" == "UP" ]]; then
    STATUS_COLOR="#89b4fa"  # Blue for online
    STATUS_TEXT="Online"
else
    STATUS_COLOR="#f38ba8"  # Red for link down
    STATUS_TEXT="Link Down"
fi

# Get public IP (cached for 5 minutes to avoid API spam)
PUBLIC_IP_CACHE="${WARMIND_STATE_DIR}/public_ip_cache"
migrate_legacy_state "/tmp/waybar_public_ip_cache" "$PUBLIC_IP_CACHE"
CACHE_TIME=300  # 5 minutes

# --fail so an HTTP error status is an error instead of a body: without it a 502
# error page was cached for 5 minutes and rendered as the public IP. The cache is
# written only on a real fetch, so a failed fetch can never poison it and the last
# known good value survives a transient outage.
fetch_public_ip() {
    local ip
    if ! command -v curl &>/dev/null; then
        echo "N/A (curl not installed)"
        return
    fi
    if ip=$(curl -s --fail --max-time 3 icanhazip.com 2>/dev/null) && [[ -n "$ip" ]]; then
        echo "$ip" > "$PUBLIC_IP_CACHE"
        echo "$ip"
    else
        echo "N/A"
    fi
}

if [[ -f "$PUBLIC_IP_CACHE" ]]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$PUBLIC_IP_CACHE" 2>/dev/null || echo 0) ))
    if [[ $CACHE_AGE -lt $CACHE_TIME ]]; then
        PUBLIC_IP=$(cat "$PUBLIC_IP_CACHE")
    else
        PUBLIC_IP=$(fetch_public_ip)
    fi
else
    PUBLIC_IP=$(fetch_public_ip)
fi

# Build display text with only the icon
DISPLAY_TEXT="<span font_desc='JetBrainsMono Nerd Font 14' color='${STATUS_COLOR}'>${ICON}</span>"

# Build tooltip with network info
TOOLTIP="<span color='${STATUS_COLOR}'>${ICON} ${CONNECTION_NAME}</span> - <span color='${STATUS_COLOR}'>${STATUS_TEXT}</span>"$'\n\n'
TOOLTIP+=" Traffic"$'\n'
TOOLTIP+="├─ Download: ${RX_RATE_HUMAN}"$'\n'
TOOLTIP+="└─ Upload: ${TX_RATE_HUMAN}"$'\n\n'
TOOLTIP+=" Local IP: ${IP_ADDR}"$'\n'
TOOLTIP+="󱦂 Public IP: ${PUBLIC_IP}"$'\n\n'
TOOLTIP+="󰌘 Connection Details"$'\n'
TOOLTIP+="├─ Name: ${CONNECTION_NAME}"$'\n'
TOOLTIP+="├─ Type: ${NETWORK_TYPE}"$'\n'
TOOLTIP+="├─ Interface: ${INTERFACE}"$'\n'
if [[ "$VPN_ACTIVE" == true ]]; then
    TOOLTIP+="└─󰌆 VPN: Active"$'\n\n'
else
    TOOLTIP+="└─󰷖 VPN: Inactive"$'\n\n'
fi
TOOLTIP+="󰳽 Click to open network settings"

# Set class based on status
if [[ "$VPN_ACTIVE" == true ]]; then
    WAYBAR_CLASS="vpn"
elif [[ "$LINK_STATUS" == "UP" ]]; then
    # A missing ping must not be read as "no internet": the probe was simply not
    # run, and reporting the link-down class for a missing 8 KB binary would be a
    # lie the user cannot act on. Fall back to the link status.
    if ! command -v ping &>/dev/null; then
        WAYBAR_CLASS="${NETWORK_TYPE}"
    elif ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        WAYBAR_CLASS="${NETWORK_TYPE}"
    else
        WAYBAR_CLASS="no-internet"
    fi
else
    WAYBAR_CLASS="disconnected"
fi

# Output JSON for waybar
echo "{\"text\":$(wb_json_escape "${DISPLAY_TEXT}"),\"tooltip\":$(wb_json_escape "${TOOLTIP}"),\"class\":$(wb_json_escape "${WAYBAR_CLASS}")}"

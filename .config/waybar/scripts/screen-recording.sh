#!/bin/bash


set -euo pipefail
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

# pgrep (procps) is what decides whether a recording is running. Without it the
# old script took the "not recording" branch and offered "Click to start screen
# recording" -- a button that would then start a second recording on top of the
# one already running. Say the state is unknown instead.
if ! command -v pgrep &>/dev/null; then
  echo '{"text": "<span size=\"140%\"></span> ", "tooltip": "pgrep not installed - recording state unknown", "class": "error"}'
  exit 0
fi

if pgrep -f "^gpu-screen-recorder" >/dev/null; then
  icons=("󰑊" "󰻂" "󰻃")
  icon_index=$(( $(date +%s) % ${#icons[@]} ))

  # The format keeps its spaces after each colon, and the icon arrives already
  # escaped, so the bytes on the wire are the ones this module always printed.
  printf '{"text": %s, "tooltip": "Click to stop screen recording", "class": "active"}\n' "$(wb_json_escape "${icons[$icon_index]}")"
else
  echo '{"text": "<span size=\"140%\"></span> ", "tooltip": "Click to start screen recording"}'
fi

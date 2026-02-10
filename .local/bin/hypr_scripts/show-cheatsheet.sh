#!/usr/bin/env bash

set -euo pipefail

socket="${XDG_RUNTIME_DIR:-}/foot.sock"
cmd=("$HOME/.config/hypr/scripts/cheatsheet.sh")

if [[ -n "$socket" && -S "$socket" ]]; then
  exec uwsm app -- footclient -s "$socket" -a hypr-cheatsheet --title "Hypr Cheatsheet" "${cmd[@]}"
fi

if command -v foot >/dev/null 2>&1; then
  exec foot --app-id hypr-cheatsheet --title "Hypr Cheatsheet" "${cmd[@]}"
fi

exec "${cmd[@]}"

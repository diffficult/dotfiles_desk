#!/usr/bin/env bash

set -euo pipefail

mode="${1:-}"
target="${2:-}"

sound_file="/home/rx/.local/bin/hypr_scripts/nothing_sounds/ui/screenshot.ogg"
icon_name="accessories-screenshot"
app_name="Screenshot (grim)"
timeout_ms=3000

if [[ -z "$mode" || -z "$target" ]]; then
  exit 1
fi

if [[ "$target" == "file-clipboard" ]]; then
  dir="$HOME/Pictures/Screenshots"
  mkdir -p "$dir"
  timestamp="$(date +%F_%H-%M-%S)"
  if [[ "$mode" == "region" ]]; then
    file="$dir/Screenshot-region-$timestamp.png"
    grim -g "$(slurp)" "$file"
  elif [[ "$mode" == "fullscreen" ]]; then
    file="$dir/Screenshot-full-$timestamp.png"
    grim "$file"
  else
    exit 1
  fi

  wl-copy < "$file"
  paplay --volume=42598 "$sound_file" || true
  notify-send --app-name="$app_name" --icon="$icon_name" -t "$timeout_ms" "Screenshot (${mode})" "$file"
  exit 0
fi

if [[ "$target" == "clipboard" ]]; then
  if [[ "$mode" == "region" ]]; then
    grim -g "$(slurp)" - | wl-copy
  elif [[ "$mode" == "fullscreen" ]]; then
    grim - | wl-copy
  else
    exit 1
  fi

  paplay --volume=42598 "$sound_file" || true
  notify-send --app-name="$app_name" --icon="$icon_name" -t "$timeout_ms" "Screenshot (${mode})" "Copied to clipboard"
  exit 0
fi

exit 1

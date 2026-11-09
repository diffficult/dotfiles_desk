#!/bin/bash

screenrecord_script="$HOME/.config/hypr/scripts/screenrecord.sh"

if pgrep -f "^gpu-screen-recorder" >/dev/null; then
  exec "$screenrecord_script" --stop-recording
fi

choice=$(printf '%s\n' \
  'With no audio' \
  'With desktop audio' \
  'With desktop + microphone audio' | rofi -dmenu -i -p 'Screenrecord')

case "$choice" in
"With no audio") exec "$screenrecord_script" ;;
"With desktop audio") exec "$screenrecord_script" --with-desktop-audio ;;
"With desktop + microphone audio") exec "$screenrecord_script" --with-desktop-audio --with-microphone-audio ;;
esac

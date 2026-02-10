#!/bin/bash

# Emergency lockscreen - use if video lock fails

# Kill all lock screens
pkill -9 swaylock
pkill -9 swaylock-plugin
pkill -9 hyprlock
pkill mpvpaper
killall swww-daemon

# Simple reliable lock
hyprlock &

# Restore wallpaper after unlock
wait
swww-daemon &
swww img "$(find ~/.config/hypr/wallpapers /usr/share/backgrounds/ -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | shuf -n 1)"

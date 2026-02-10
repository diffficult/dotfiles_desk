#!/bin/bash

# Simple fallback lockscreen (always works)
pkill swaylock
pkill swaylock-plugin
pkill hyprlock
pkill mpvpaper
killall swww-daemon
hyprlock
swww-daemon &
swww img "$(find ~/.config/hypr/wallpapers /usr/share/backgrounds/ -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | shuf -n 1)"

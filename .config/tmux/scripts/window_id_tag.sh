#!/usr/bin/env bash
# Window ID tag generator for tmux
# Returns the appropriate symbol for the given window index and state

window_index="$1"
window_flags="$2"
style="${3:-fsquare}"

# Determine if this is the active window
is_active=0
[[ "$window_flags" == *"*"* ]] && is_active=1

# Select symbol set based on style and active state
case "$style" in
  fsquare)
    if [ $is_active -eq 1 ]; then
      symbols="${TMUX_WINDOW_ID_FSQUARE_ACTIVE:-󰎤 󰎧 󰎪 󰎭 󰎱 󰎳 󰎶 󰎹 󰎼 󰎡}"
    else
      # When style is fsquare, inactive windows use hsquare symbols
      symbols="${TMUX_WINDOW_ID_HSQUARE_INACTIVE:-󰎦 󰎩 󰎬 󰎮 󰎰 󰎵 󰎸 󰎻 󰎾 󰎣}"
    fi
    ;;
  hsquare)
    if [ $is_active -eq 1 ]; then
      symbols="${TMUX_WINDOW_ID_HSQUARE_ACTIVE:-󰎦 󰎩 󰎬 󰎮 󰎰 󰎵 󰎸 󰎻 󰎾 󰎣}"
    else
      symbols="${TMUX_WINDOW_ID_HSQUARE_INACTIVE:-󰬺 󰬻 󰬼 󰬽 󰬾 󰬿 󰭀 󰭁 󰭂 󰿩}"
    fi
    ;;
  digital)
    if [ $is_active -eq 1 ]; then
      symbols="${TMUX_WINDOW_ID_DIGITAL_ACTIVE:-󰲠 󰲢 󰲤 󰲦 󰲨 󰲪 󰲬 󰲮 󰲰 󰿬}"
    else
      symbols="${TMUX_WINDOW_ID_DIGITAL_INACTIVE:-󰲡 󰲣 󰲥 󰲧 󰲩 󰲫 󰲭 󰲯 󰲱 󰿩}"
    fi
    ;;
  roman)
    if [ $is_active -eq 1 ]; then
      symbols="${TMUX_WINDOW_ID_ROMAN_ACTIVE:-󰼏 󰼐 󰼑 󰼒 󰼓 󰼔 󰼕 󰼖 󰼗 󰼎}"
    else
      symbols="${TMUX_WINDOW_ID_ROMAN_INACTIVE:-󰎦 󰎩 󰎬 󰎮 󰎰 󰎵 󰎸 󰎻 󰎾 󰎣}"
    fi
    ;;
  super)
    symbols="${TMUX_WINDOW_ID_SUPER:-1 2 3 4 5 6 7 8 9 0}"
    ;;
  sub)
    symbols="${TMUX_WINDOW_ID_SUB:-₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₁₀}"
    ;;
  *)
    echo "$window_index"
    exit 0
    ;;
esac

# Convert space-separated string to array and get symbol
IFS=' ' read -ra symbol_array <<< "$symbols"
if [ "$window_index" -ge 1 ] && [ "$window_index" -le "${#symbol_array[@]}" ]; then
  echo "${symbol_array[$((window_index - 1))]}"
else
  echo "$window_index"
fi

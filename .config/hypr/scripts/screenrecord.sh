#!/bin/bash

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs

OUTPUT_DIR="${SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}}"
DESKTOP_AUDIO="false"
MICROPHONE_AUDIO="false"
STOP_RECORDING="false"
RECORDING_FILE="/tmp/hypr-screenrecord-filename"
export GTK_THEME="Nordic-darker"

require_commands() {
  local missing=()
  local command_name

  for command_name in gpu-screen-recorder hyprctl jq notify-send ffmpeg; do
    command -v "$command_name" >/dev/null || missing+=("$command_name")
  done

  if (( ${#missing[@]} > 0 )); then
    notify-send "Screen recording dependencies missing" "Install: ${missing[*]}" -u critical -t 5000
    exit 1
  fi
}

for arg in "$@"; do
  case "$arg" in
  --with-desktop-audio) DESKTOP_AUDIO="true" ;;
  --with-microphone-audio) MICROPHONE_AUDIO="true" ;;
  --stop-recording) STOP_RECORDING="true" ;;
  esac
done

if [[ ! -d $OUTPUT_DIR ]]; then
  notify-send "Screen recording directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

require_commands

signal_waybar() {
  pkill -RTMIN+8 waybar 2>/dev/null
}

screenrecording_active() {
  pgrep -f "^gpu-screen-recorder" >/dev/null
}

default_resolution() {
  local width height

  read -r width height < <(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.width) \(.height)"')

  if ((width > 3840 || height > 2160)); then
    echo "3840x2160"
  else
    echo "0x0"
  fi
}

trim_first_frame() {
  local latest trimmed

  latest=$(<"$RECORDING_FILE")

  if [[ -n $latest && -f $latest ]]; then
    trimmed="${latest%.mp4}-trimmed.mp4"

    if ffmpeg -y -ss 0.1 -i "$latest" -c copy "$trimmed" -loglevel quiet 2>/dev/null; then
      mv "$trimmed" "$latest"
    else
      rm -f "$trimmed"
    fi
  fi
}

start_screenrecording() {
  local filename audio_devices resolution pid
  local audio_args=()

  filename="$OUTPUT_DIR/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S').mp4"
  audio_devices=""

  [[ $DESKTOP_AUDIO == "true" ]] && audio_devices+="default_output"

  if [[ $MICROPHONE_AUDIO == "true" ]]; then
    [[ -n $audio_devices ]] && audio_devices+="|"
    audio_devices+="default_input"
  fi

  [[ -n $audio_devices ]] && audio_args+=(-a "$audio_devices" -ac aac)

  resolution=$(default_resolution)

  gpu-screen-recorder -w portal -k auto -s "$resolution" -f 60 -fm cfr -fallback-cpu-encoding yes -o "$filename" "${audio_args[@]}" &
  pid=$!

  while kill -0 $pid 2>/dev/null && [[ ! -f $filename ]]; do
    sleep 0.2
  done

  if kill -0 $pid 2>/dev/null; then
    printf '%s\n' "$filename" >"$RECORDING_FILE"
    signal_waybar
  fi
}

stop_screenrecording() {
  local count filename preview action

  pkill -SIGINT -f "^gpu-screen-recorder"

  count=0
  while pgrep -f "^gpu-screen-recorder" >/dev/null && ((count < 50)); do
    sleep 0.1
    ((count++))
  done

  signal_waybar

  if pgrep -f "^gpu-screen-recorder" >/dev/null; then
    pkill -9 -f "^gpu-screen-recorder"
    notify-send "Screen recording error" "Recording process had to be force-killed. Video may be corrupted." -u critical -t 5000
    rm -f "$RECORDING_FILE"
    exit 1
  fi

  trim_first_frame

  if [[ -f $RECORDING_FILE ]]; then
    filename=$(<"$RECORDING_FILE")
    preview="${filename%.mp4}-preview.png"

    ffmpeg -y -i "$filename" -ss 00:00:00.1 -vframes 1 -q:v 2 "$preview" -loglevel quiet 2>/dev/null

    (
      action=$(notify-send "Screen recording saved" "Click to open recording" -t 10000 -i "${preview:-$filename}" -A "default=open")
      [[ $action == "default" ]] && mpv "$filename"
      rm -f "$preview"
    ) &
  fi

  rm -f "$RECORDING_FILE"
}

if screenrecording_active; then
  stop_screenrecording
elif [[ $STOP_RECORDING == "true" ]]; then
  exit 1
else
  start_screenrecording
fi

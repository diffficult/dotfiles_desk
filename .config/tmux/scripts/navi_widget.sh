#!/usr/bin/env sh

set -eu

pane_path=${1:-$HOME}
shell_bin=${SHELL:-/bin/sh}

tmux split-window -c "$pane_path" "$shell_bin --login -i -c 'navi --print | head -n 1 | tmux load-buffer -b tmp - ; tmux paste-buffer -p -t {last} -b tmp -d'"

#!/usr/bin/env bash
set -euo pipefail

live_expose="$HOME/.config/warmind/modules/expose"
live_modules_conf="$HOME/.config/warmind/modules/modules.conf"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
repo_expose="$repo_root/config/warmind/modules/expose"

# Is expose in the module list? Presence means enabled; see
# config/warmind/modules/modules.conf. A missing or unreadable list means
# nothing is enabled, which is the same answer the deploy engine reaches: it
# would not have written an autostart entry for expose either.
expose_enabled() {
  local line
  [[ -f "$live_modules_conf" && -r "$live_modules_conf" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ "$line" == "expose" ]] && return 0
  done <"$live_modules_conf"
  return 1
}

# SUPER + grave stays bound whatever the list says. This script is what the bind
# invokes, and it is inert while expose is disabled, so the key does nothing
# instead of starting a shell the owner switched off.
if ! expose_enabled; then
  echo "warmind expose: disabled (not listed in $live_modules_conf)" >&2
  echo "warmind expose: run 'warmind-deploy modules enable expose' and deploy to turn it on" >&2
  exit 1
fi

pick_expose_path() {
  if [[ -d "$live_expose" ]]; then
    printf '%s\n' "$live_expose"
    return 0
  fi
  if [[ -d "$repo_expose" ]]; then
    printf '%s\n' "$repo_expose"
    return 0
  fi
  return 1
}

expose_path="$(pick_expose_path)" || {
  echo "warmind expose: expose config not found" >&2
  exit 1
}

if qs -c "$expose_path" ipc call expose toggle >/dev/null 2>&1; then
  exit 0
fi

if command -v uwsm >/dev/null 2>&1; then
  nohup uwsm app -- qs -n -d -c "$expose_path" >/tmp/warmind-expose.log 2>&1 &
else
  nohup qs -n -d -c "$expose_path" >/tmp/warmind-expose.log 2>&1 &
fi

for _ in $(seq 1 40); do
  if qs -c "$expose_path" ipc call expose toggle >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
done

echo "warmind expose: failed to reach expose IPC after start" >&2
exit 1

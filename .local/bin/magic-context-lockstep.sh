#!/usr/bin/env bash
#
# magic-context-lockstep
#
# Keeps opencode's @cortexkit/opencode-magic-context version in lockstep with
# pi's @cortexkit/pi-magic-context version.
#
# WHY: both harnesses share one SQLite database at
#   $XDG_DATA_HOME/cortexkit/magic-context/context.db
# The binary refuses to open the DB when the DB's schema version is newer than
# what the binary supports (the "schema fence"). pi declares its magic-context
# as "^0.38.0" (caret), so pi drifts forward and migrates the shared DB ahead;
# a frozen opencode plugin then fails with "persistent storage unavailable".
# This script makes opencode always track pi, so opencode always supports >=
# the DB schema.
#
# Safe: only acts on version mismatch. Idempotent. Never touches the DB or pi.

set -uo pipefail

HOME="${HOME:-/home/rx}"
PI_PKG="$HOME/.pi/agent/npm/node_modules/@cortexkit/pi-magic-context"
OC_CACHE_BASE="$HOME/.cache/opencode/packages"
CONFIGS=(
  "$HOME/.config/opencode/opencode.json"
  "$HOME/.config/opencode/tui.json"
  "$HOME/.config/opencode/cli.json"
)
PLUGIN_ID="opencode-magic-context"
LOG_DIR="$HOME/.local/share/magic-context-lockstep"
LOG="$LOG_DIR/lockstep.log"
OPCODE_BIN="$(command -v opencode || echo "$HOME/.local/share/mise/installs/opencode/latest/opencode")"

mkdir -p "$LOG_DIR"
log() { echo "$(date -Is) $*" >> "$LOG"; }

# 1) Resolve pi's current version (the source of truth for the shared DB).
if [ ! -f "$PI_PKG/package.json" ]; then
  log "SKIP: pi-magic-context not found at $PI_PKG"
  exit 0
fi
PI_VER="$(grep -m1 '"version"' "$PI_PKG/package.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [ -z "$PI_VER" ]; then
  log "SKIP: could not read pi version"
  exit 0
fi

# 2) Resolve opencode's currently configured version.
OC_VER=""
for cfg in "${CONFIGS[@]}"; do
  if [ -f "$cfg" ]; then
    OC_VER="$(grep -oE "@cortexkit/$PLUGIN_ID@[^\"]+" "$cfg" | head -1 | sed -E 's/.*@([^@]+)$/\1/')"
    [ -n "$OC_VER" ] && break
  fi
done
if [ -z "$OC_VER" ]; then
  log "SKIP: opencode magic-context entry not found in configs"
  exit 0
fi

if [ "$OC_VER" = "$PI_VER" ]; then
  log "OK: opencode ($OC_VER) == pi ($PI_VER); no action"
  exit 0
fi

log "MISMATCH: opencode=$OC_VER pi=$PI_VER -> syncing opencode to pi"

# 3) Pin opencode's config entry to pi's exact version in every config file.
NEW_ENTRY="@cortexkit/$PLUGIN_ID@$PI_VER"
for cfg in "${CONFIGS[@]}"; do
  [ -f "$cfg" ] || continue
  sed -i -E "s#\"@cortexkit/$PLUGIN_ID@[^\"]+\"#\"$NEW_ENTRY\"#g" "$cfg"
done
log "configs updated to $NEW_ENTRY"

# 4) Ensure the plugin cache for the new version exists (fetch if needed).
if [ -x "$OPCODE_BIN" ]; then
  "$OPCODE_BIN" plugin -g "$NEW_ENTRY" >> "$LOG" 2>&1 \
    && log "opencode plugin cache ensured for $NEW_ENTRY" \
    || log "WARN: 'opencode plugin -g $NEW_ENTRY' returned non-zero (offline or transient)"
else
  log "WARN: opencode binary not found; cache not refreshed. Fix manually."
fi

# 5) Remove stale cache dirs for this plugin that don't match the current spec.
KEEP="$PLUGIN_ID@$PI_VER"  # basename has no @cortexkit/ prefix
for d in "$OC_CACHE_BASE"/@cortexkit/"$PLUGIN_ID"@*; do
  [ -d "$d" ] || continue
  base="$(basename "$d")"
  if [ "$base" != "$KEEP" ]; then
    rm -rf "$d" && log "removed stale cache: $base"
  fi
done

log "done"

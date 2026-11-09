#!/usr/bin/env bash
#
# magic-context-release-watch
#
# Event-driven (polling) updater for magic-context across both harnesses.
#
# cortexkit publishes @cortexkit/opencode-magic-context and
# @cortexkit/pi-magic-context in lockstep. Both harnesses share one SQLite DB
# (~/.local/share/cortexkit/magic-context/context.db); the binary refuses to
# open the DB when the DB schema is newer than it supports (the "schema fence").
# If one harness upgrades and migrates the DB while the other is stale, the
# stale one breaks with "persistent storage unavailable".
#
# This watcher polls npm for a new magic-context release and, on a new version,
# upgrades BOTH harnesses to that exact version so they stay in lockstep and the
# shared DB never strand either binary.
#
# Safe: no-op when already at latest; updates are the supported package-manager
# paths (opencode plugin / pi update); never touches the DB directly.

set -uo pipefail

HOME="${HOME:-/home/rx}"
STATE_DIR="$HOME/.local/share/magic-context-lockstep"
STATE="$STATE_DIR/last-release"
LOG="$STATE_DIR/release-watch.log"
OC_PKG="@cortexkit/opencode-magic-context"
PI_PKG_SRC="npm:@cortexkit/pi-magic-context"
PLUGIN_ID="opencode-magic-context"
OC_CACHE_BASE="$HOME/.cache/opencode/packages"
CONFIGS=(
  "$HOME/.config/opencode/opencode.json"
  "$HOME/.config/opencode/tui.json"
  "$HOME/.config/opencode/cli.json"
)
OPCODE_BIN="$(command -v opencode || echo "$HOME/.local/share/mise/installs/opencode/latest/opencode")"
PI_BIN="$(command -v pi || echo "$HOME/.local/share/mise/installs/pi/latest/pi/pi")"

mkdir -p "$STATE_DIR"
log() { echo "$(date -Is) $*" >> "$LOG"; }

# 1) Latest published version on npm (cortexkit publishes both packages in lockstep).
LATEST="$(npm view "$OC_PKG" version 2>/dev/null | tail -1 | tr -d ' \t\r')"
if [ -z "$LATEST" ]; then
  log "SKIP: could not read npm latest for $OC_PKG (offline?)"
  exit 0
fi

# 2) Compare to last applied release.
LAST=""
[ -f "$STATE" ] && LAST="$(cat "$STATE")"
if [ "$LAST" = "$LATEST" ]; then
  log "OK: npm latest ($LATEST) already applied; no action"
  exit 0
fi

log "NEW RELEASE: npm latest=$LATEST (last applied=$LAST) -> updating both harnesses"

# 3) Update pi's magic-context extension first (supported path; does not touch
#    the pi binary, which mise manages). Caret range pulls the new latest.
if [ -x "$PI_BIN" ]; then
  "$PI_BIN" update --no-approve "$PI_PKG_SRC" >> "$LOG" 2>&1 \
    && log "pi updated ($PI_PKG_SRC -> $LATEST)" \
    || log "WARN: 'pi update $PI_PKG_SRC' returned non-zero"
else
  log "WARN: pi binary not found; pi not updated"
fi

# 4) Update opencode to the exact same version (so both harnesses are identical).
#    NOTE: 'opencode plugin -g' only ensures the cache; it does NOT switch the
#    config entry when the plugin is already configured under a different spec.
#    So we edit the configs directly, then ensure the cache for the new version.
NEW_ENTRY="$OC_PKG@$LATEST"
for cfg in "${CONFIGS[@]}"; do
  [ -f "$cfg" ] || continue
  sed -i -E "s#\"@cortexkit/$PLUGIN_ID@[^\"]+\"#\"$NEW_ENTRY\"#g" "$cfg"
done
log "opencode configs set to $NEW_ENTRY"
if [ -x "$OPCODE_BIN" ]; then
  "$OPCODE_BIN" plugin -g "$NEW_ENTRY" >> "$LOG" 2>&1 \
    && log "opencode plugin cache ensured for $NEW_ENTRY" \
    || log "WARN: 'opencode plugin -g $NEW_ENTRY' returned non-zero"
else
  log "WARN: opencode binary not found"
fi

# 5) Remove stale opencode-magic-context cache dirs (keep the applied version).
KEEP="$PLUGIN_ID@$LATEST"
for d in "$OC_CACHE_BASE"/@cortexkit/"$PLUGIN_ID"@*; do
  [ -d "$d" ] || continue
  base="$(basename "$d")"
  if [ "$base" != "$KEEP" ]; then
    rm -rf "$d" && log "removed stale cache: $base"
  fi
done

# 6) Record applied release.
echo "$LATEST" > "$STATE"
log "done (applied $LATEST)"

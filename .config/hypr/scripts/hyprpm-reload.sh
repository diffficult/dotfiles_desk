#!/bin/sh
# Login hook: load hyprpm plugins, then the locally built scrolloverview.
#
# Hyprland 0.57 changed the plugin ABI; upstream main does not build, so the
# plugin is built from `new-release` + PR #83 and installed under ~/.local/lib.
# Once upstream ships 0.57 support, delete the local load below and use
# `hyprpm add <url> origin/new-release` instead.

hyprpm reload -n >/dev/null 2>&1

# --- local scrolloverview fallback: delete this block after hyprpm can build
# --- origin/new-release against the running Hyprland (see docs/scrolloverview-recovery.md)
SO="$HOME/.local/lib/hypr/scrolloverview.so"
if [ -f "$SO" ] && ! hyprctl plugin list 2>/dev/null | grep -q 'scrolloverview'; then
  hyprctl plugin load "$SO" >/dev/null 2>&1
fi
# --- end local scrolloverview fallback

# Re-parse the Lua config now that plugin.scrolloverview.* exists. The config
# guards those keys, so the initial parse (plugin not loaded yet) is silent.
hyprctl reload >/dev/null 2>&1

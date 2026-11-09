#!/bin/sh
# Login hook: load hyprpm plugins, then re-parse the Lua config.
#
# Hyprland parses the Lua config before this script runs, so plugin.* keys are
# unknown at first parse and the config guards them. The explicit hyprctl
# reload after hyprpm reload applies those options for the session.

hyprpm reload -n >/dev/null 2>&1

# Re-parse the Lua config now that plugin.scrolloverview.* exists.
hyprctl reload >/dev/null 2>&1

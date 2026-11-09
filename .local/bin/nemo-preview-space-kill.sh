#!/bin/bash
# Space killswitch for nemo-preview: closes the preview window if one is open.
# Bound via Hyprland `bindn` (non-consuming) so space still reaches apps.
if pgrep -f "nemo-preview-start" >/dev/null 2>&1; then
    gdbus call --session \
        --dest org.nemo.Preview \
        --object-path /org/nemo/Preview \
        --method org.nemo.Preview.Close >/dev/null 2>&1
fi
exit 0

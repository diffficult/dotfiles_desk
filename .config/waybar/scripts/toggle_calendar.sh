#!/usr/bin/env bash
# Toggle waycal: kill if running, else detect anchor position and launch.

pkill -x waycal && exit 0

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/config.jsonc"

ANCHOR=$(python3 - "$CONFIG" <<'EOF'
import json, re, sys

try:
    with open(sys.argv[1]) as f:
        # Strip // line comments (simple, handles most JSONC)
        txt = re.sub(r'//[^\n]*', '', f.read())
    data = json.loads(txt)
except Exception:
    print('center')
    sys.exit(0)

configs = data if isinstance(data, list) else [data]
for cfg in configs:
    if 'custom/calendar-script' in cfg.get('modules-right', []):
        print('right'); sys.exit(0)
    if 'custom/calendar-script' in cfg.get('modules-center', []):
        print('center'); sys.exit(0)
    if 'custom/calendar-script' in cfg.get('modules-left', []):
        print('left'); sys.exit(0)
print('center')
EOF
)

exec waycal --anchor "${ANCHOR:-center}"

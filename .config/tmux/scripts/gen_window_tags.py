#!/usr/bin/env python3
"""Print the window-index tag fragments for tmux_conf_theme_window_status[_current]_format.

The old format called scripts/window_id_tag.sh through #(), which runs a shell,
bash and an array parser on *every* status redraw. With an animated spinner that
was 6 forks per frame. The tag only depends on the window index, so it is a pure
function of a tmux variable and can be expanded natively, for free.

Changing style means regenerating these two fragments and pasting them in:

    scripts/gen_window_tags.py            # current style: fsquare
    scripts/gen_window_tags.py roman      # any style window_id_tag.sh knows
"""

import os
import re
import sys

STYLES = ("fsquare", "hsquare", "digital", "roman", "super", "sub")


def table(style):
    """The ten glyphs of each state, read from the script's own symbol tables."""
    text = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "window_id_tag.sh")).read()
    # The ten glyphs of each state live in the case arm for this style.
    arm = text.split(f"  {style})")[1].split(";;")[0]
    sets = [line.split(":-", 1)[1].rstrip('}"').strip() for line in arm.splitlines() if ":-" in line]
    return [s.split() for s in sets]


def fragment(glyphs):
    """Nested conditional: index 1..10 -> glyph, anything else -> the index itself."""
    out = "#{window_index}"
    for index in range(len(glyphs), 0, -1):
        out = f"#{{?#{{==:#{{window_index}},{index}}},{glyphs[index - 1]},{out}}}"
    return out


def configured_style(default="fsquare"):
    """tmux_conf_window_id_style from tmux.conf.local, so a bare run matches it."""
    try:
        text = open(os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "tmux.conf.local")).read()
    except OSError:
        return default
    found = re.search(r'^tmux_conf_window_id_style="?([a-z]+)"?', text, re.M)
    return found.group(1) if found else default


def main():
    style = sys.argv[1] if len(sys.argv) > 1 else configured_style()
    if style not in STYLES:
        raise SystemExit(f"usage: {sys.argv[0]} [{'|'.join(STYLES)}]")
    try:
        sets = table(style)
    except (IndexError, ValueError):
        raise SystemExit(f"could not read the {style!r} symbol table from window_id_tag.sh")
    if len(sets) == 1:  # super/sub have a single set, active or not
        sets = sets * 2
    active, inactive = sets
    print(f"# {style}: active window")
    print(fragment(active))
    print(f"# {style}: other windows")
    print(fragment(inactive))


if __name__ == "__main__":
    main()

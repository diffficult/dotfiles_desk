#!/usr/bin/env python3
"""
waybar_gcal_bar.py - Waybar bar widget for the calendar module.
Reads today's events from the Google Calendar cache and outputs waybar JSON.
"""
import datetime
import json
import sys
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "waybar" / "gcal"
CACHE_TTL_HOURS = 4


def get_today_events(cache_dir: Path = CACHE_DIR) -> tuple:
    """Return (events_today: list, is_stale: bool)."""
    today = datetime.date.today()
    cache_path = cache_dir / f"events_{today.strftime('%Y-%m')}.json"

    if not cache_path.exists():
        return [], True

    data = json.loads(cache_path.read_text())
    age = datetime.datetime.now() - datetime.datetime.fromisoformat(data["fetched_at"])
    stale = age.total_seconds() > CACHE_TTL_HOURS * 3600

    today_str = today.strftime("%Y-%m-%d")
    events = [e for e in data.get("events", []) if e["date"] == today_str]
    return events, stale


def build_bar_output(events: list, stale: bool) -> dict:
    """Build the waybar JSON output dict."""
    count = len(events)

    if stale and count == 0:
        return {
            "text": "<span size='14pt'> ⚠ </span>",
            "tooltip": "Calendar data stale or unavailable",
            "class": "calendar-empty",
            "alt": "0",
        }

    if count > 0:
        stale_badge = " ⚠" if stale else ""
        text = f"<span size='14pt'>󰃭 {count}{stale_badge}</span>"
        tooltip_lines = [
            f"{e['start_time']}  {e['title']}" for e in events
        ]
        return {
            "text": text,
            "tooltip": "\n".join(tooltip_lines),
            "class": "calendar-active",
            "alt": str(count),
        }

    return {
        "text": "<span size='14pt'>󰃮 </span>",
        "tooltip": "No events today",
        "class": "calendar-empty",
        "alt": "0",
    }


def main() -> None:
    events, stale = get_today_events()
    print(json.dumps(build_bar_output(events, stale)))


if __name__ == "__main__":
    main()

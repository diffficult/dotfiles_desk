#!/usr/bin/env python3
import subprocess
import json
import html
import datetime
import sys

def get_khal_events():
    # format: start-date|start-time|title|calendar
    cmd = ["khal", "list", "now", "7d", "--format", "{start-date}|{start-time}|{title}|{calendar}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            return []
        return result.stdout.strip().split('\n')
    except Exception as e:
        return []

def parse_date(date_str):
    try:
        return datetime.datetime.strptime(date_str.strip(), "%Y-%m-%d").date()
    except ValueError:
        return datetime.date.today()

def main():
    raw_lines = get_khal_events()
    events = []
    today = datetime.date.today()
    tomorrow = today + datetime.timedelta(days=1)
    
    # Color mapping (Substring matching)
    # Checks if key is in the calendar name (case-insensitive)
    color_map = [
        ("family", "#40a02b"),       # Family -> Green
        ("spaulo", "#dd7878"),       # Personal -> Flamingo
        ("gp8r", "#1e66f5"),        # Consultas -> Blue
        ("cln2", "#ea76cb"),        # Holidays/Tasks -> Pink
        ("birthday", "#df8e1d"),     # Birthdays -> Yellow
    ]
    default_color = "#cdd6f4"
    
    # Parse lines
    for line in raw_lines:
        if "|" not in line:
            continue
            
        parts = line.split('|')
        if len(parts) >= 4:
            s_date, s_time, title, calendar = parts[:4]
            
            s_date = s_date.strip()
            s_time = s_time.strip()
            title = title.strip()
            calendar = calendar.strip()
            
            event_date = parse_date(s_date)
            
            events.append({
                "date_obj": event_date,
                "date_str": s_date,
                "time": s_time,
                "title": title,
                "calendar": calendar
            })
    
    # Count today's events
    today_events = [e for e in events if e["date_obj"] == today]
    today_count = len(today_events)
    
    # Tooltip Logic
    tooltip_lines = []
    display_limit = 10 
    shown_count = 0
    current_header = None
    
    for e in events:
        if shown_count >= display_limit:
            break
            
        # Header Logic
        if e["date_obj"] == today:
            header = "Today"
        elif e["date_obj"] == tomorrow:
            header = "Tomorrow"
        else:
            header = e["date_obj"].strftime("%A, %b %d")
            
        if header != current_header:
            if shown_count > 0:
                tooltip_lines.append("")
            tooltip_lines.append(f"<b><u>{header}</u></b>")
            current_header = header
            
        # Color Logic
        cal_name = e['calendar'].lower()
        color = default_color
        for key, val in color_map:
            if key in cal_name:
                color = val
                break
        
        # Icon Logic
        icon = ""
        lower_title = e['title'].lower()
        
        if "jane" in lower_title or "romi" in lower_title:
             icon = "💅 "
        elif "mauricio" in lower_title:
             icon = "󱌻 "
        elif any(x in lower_title for x in ["dr", "doctor", "odont", "medico", "médico"]):
             icon = "👨‍⚕️ "
        elif "birthday" in lower_title or "cumple" in lower_title or "birthday" in cal_name:
             icon = "🎂 "
        elif "flight" in lower_title or "vuelo" in lower_title or "viaje" in lower_title:
             icon = "✈️ "
        
        # Construct Line
        safe_title = html.escape(e['title'])
        line = f"<span color='#a6adc8'>{e['time']}</span> <span color='{color}'>{icon}{safe_title}</span>"
        tooltip_lines.append(line)
        shown_count += 1

    if not tooltip_lines:
        tooltip_lines.append("No upcoming events")

    tooltip = "\n".join(tooltip_lines)

    # Bar Text Logic
    icon_bar = ""
    base_text = f" {icon_bar} {today_count} " if today_count > 0 else f" "
    text = f"<span size='14pt'>{base_text}</span>"
    class_name = "calendar-active" if today_count > 0 else "calendar-empty"

    output = {
        "text": text,
        "tooltip": tooltip,
        "class": class_name,
        "alt": str(today_count)
    }

    print(json.dumps(output))

if __name__ == "__main__":
    main()

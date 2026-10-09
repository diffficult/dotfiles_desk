#!/usr/bin/env python3
"""
calendar_daemon.py - Warmind Waybar calendar state manager.

Despite the name this is not a daemon: it is a one-shot CLI, run per user
action, that rewrites state.json atomically. calendar-bar-output.py, the Waybar
module polled every 60s, imports load_month() from here.

Usage:
  calendar_daemon.py --init              # Open: load current month, today selected
  calendar_daemon.py --prev              # Navigate to previous month
  calendar_daemon.py --next              # Navigate to next month
  calendar_daemon.py --select YYYY-MM-DD # Select a specific day

Per-account state lives in CACHE_DIR, next to the OAuth token: token.json, the
month cache, state.json, and calendar_appearance.json (which Google calendar id
maps to which colour and icon - see resolve_appearance).
"""
import argparse
import calendar
import datetime
import json
import os
import sys
import tempfile
from pathlib import Path

# The google.* client libraries are imported lazily, inside the functions that
# need them (see _google_credentials, _build_service and get_credentials). This
# module is imported by calendar-bar-output.py, a Waybar `exec` module polled
# every 60s, and a hard top-level import made a missing optional dependency
# fatal at import time -- before the module's own {"text": "..."} error path
# could run, leaving the bar with no output at all instead of an error.

SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]
CACHE_DIR = Path.home() / ".cache" / "quickshell" / "warmind" / "waybar" / "calendar"
LEGACY_CACHE_DIR = Path.home() / ".cache" / "waybar" / "gcal"
TOKEN_PATH = CACHE_DIR / "token.json"
LEGACY_TOKEN_PATH = LEGACY_CACHE_DIR / "token.json"
STATE_PATH = CACHE_DIR / "state.json"
PRIMARY_CREDS_PATH = Path.home() / ".config" / "warmind" / "waybar" / "calendar_cred.json"
LEGACY_CREDS_PATH = Path.home() / ".config" / "waybar" / "calendar_cred.json"
CREDS_PATH = Path(os.getenv("CALENDAR_CREDENTIALS_PATH", str(PRIMARY_CREDS_PATH if PRIMARY_CREDS_PATH.exists() else LEGACY_CREDS_PATH)))
CACHE_TTL_HOURS = 24
# Per-request timeout for the Google API calls. googleapiclient's own default
# is 120s; this only changes what happens when a request is already failing to
# come back, never the result of one that succeeds.
API_TIMEOUT_SECONDS = 20

CALENDAR_COLORS = {
    "Personal": "#dd7878",
    "Birthdays": "#df8e1d",
    "Consultas y Estudios": "#1e66f5",
    "Family": "#40a02b",
    "Tasks": "#ea76cb",
}
DEFAULT_COLOR = "#cdd6f4"

CALENDAR_ICONS = {
    "Personal": "󰋚",
    "Birthdays": "󰃰",
    "Consultas y Estudios": "󰈷",
    "Family": "\uf0c0 ",
    "Tasks": "󰄱",
}
DEFAULT_ICON = "󰃭"

# Machine-local map from Google's stable calendar id to the appearance we
# resolved for it: {"<id>": {"name": ..., "color": ..., "icon": ...}}.
#
# CALENDAR_COLORS/CALENDAR_ICONS stay keyed on the display name because they
# have to stay shareable: they are the defaults a fresh machine seeds from, and
# an account-specific calendar id in the repository would be wrong for every
# other account. A display name, though, is renameable on Google's side, so a
# name-keyed lookup is only as durable as the operator's naming habits. The id
# is not, so the learned answer is persisted next to the token - which is
# already this file's home for per-account state - and the name-keyed tables
# become the seed rather than the lookup.
APPEARANCE_MAP_FILENAME = "calendar_appearance.json"
APPEARANCE_MAP_VERSION = 1

# What resolve_appearance() took its answer from. Only "map" is durable across
# a rename; "default" is the name seed, which a rename invalidates; "fallback"
# means nothing was configured and the calendar counts as unmapped.
SOURCE_MAP = "map"
SOURCE_DEFAULT = "default"
SOURCE_MIXED = "mixed"
SOURCE_FALLBACK = "fallback"


def _google_credentials():
    """Import google.oauth2.credentials lazily, with an actionable message."""
    try:
        from google.oauth2.credentials import Credentials
    except ImportError as exc:
        raise RuntimeError(
            "the Google API client libraries are not installed "
            "(pip install google-api-python-client google-auth-httplib2 "
            "google-auth-oauthlib)"
        ) from exc
    return Credentials


def _build_service(creds):
    """Build the Calendar v3 service with an explicit request timeout.

    googleapiclient applies a 120s default; 20s bounds a hung request without
    changing the outcome of one that completes.

    The transport must be httplib2-shaped, because googleapiclient calls
    ``http.request(uri, method, body=..., headers=...)`` - the httplib2
    signature. A `requests`-style AuthorizedSession does NOT accept `body`,
    and it fails at the first real request with
    "Session.request() got an unexpected keyword argument 'body'".

    Constructing a discovery Resource is lazy - it never touches the network -
    so building one successfully proves nothing about whether a request works.
    The transport is therefore asserted to be an httplib2.Http subclass, which
    is the property that actually decides it.

    And `credentials` and `http` are mutually exclusive in build(), so only the
    http is passed.
    """
    from googleapiclient.discovery import build

    try:
        import httplib2
        from google_auth_httplib2 import AuthorizedHttp
    except ImportError as exc:  # pragma: no cover - ships with google-auth
        print(
            f"[calendar_daemon] no httplib2 transport available ({exc}); "
            "using the library's default request timeout",
            file=sys.stderr,
        )
        return build("calendar", "v3", credentials=creds)

    transport = AuthorizedHttp(creds, http=httplib2.Http(timeout=API_TIMEOUT_SECONDS))
    return build("calendar", "v3", http=transport, cache_discovery=False)


def _local_timezone():
    """The machine's current local timezone as a fixed-offset tzinfo."""
    return datetime.datetime.now().astimezone().tzinfo


def month_window(year: int, month: int, tz=None) -> tuple:
    """Half-open [start, end) window covering all of `year`-`month` in `tz`.

    Built in the *local* zone on purpose. Google resolves timeMin/timeMax
    against the event's own timezone, so a UTC window silently drops events in
    the first and last hours of the local month.
    """
    if tz is None:
        tz = _local_timezone()
    start = datetime.datetime(year, month, 1, tzinfo=tz)
    next_month = month + 1 if month < 12 else 1
    next_year = year if month < 12 else year + 1
    end = datetime.datetime(next_year, next_month, 1, tzinfo=tz)
    return start, end


def _write_json_atomic(path: Path, payload: str) -> None:
    """Write `payload` to `path` via a temp file in the same dir + os.replace.

    Used for both state.json and the month cache, so a crash mid-write can
    never leave a half-written JSON file behind for the reader to trip over.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False, suffix=".tmp") as f:
            f.write(payload)
            tmp = f.name
        os.replace(tmp, path)
    except OSError:
        # os.replace is the only failure point; drop the temp file rather than
        # leaving debris next to the cache on every failed write.
        if tmp is not None:
            Path(tmp).unlink(missing_ok=True)
        raise


def _appearance_map_path() -> Path:
    """Where the id -> appearance map lives. Derived from CACHE_DIR, not a
    module constant, so redirecting the cache redirects the map with it."""
    return CACHE_DIR / APPEARANCE_MAP_FILENAME


def load_appearance_map() -> dict:
    """Read the id -> appearance map; return {} when absent or unreadable.

    A truncated or hand-edited map is treated exactly as a missing one, for the
    same reason load_month treats a truncated cache as a miss: this file is
    rewritten by a Waybar poll, so a crash mid-write must degrade to the repo
    defaults instead of taking the calendar module down. `resolve_appearance`
    re-seeds every calendar it sees, so the map rebuilds itself on the next
    fetch.
    """
    path = _appearance_map_path()
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        print(
            f"[calendar_daemon] ignoring unreadable calendar appearance map {path}: {exc}",
            file=sys.stderr,
        )
        return {}
    if not isinstance(data, dict) or not isinstance(data.get("calendars"), dict):
        print(
            f"[calendar_daemon] ignoring calendar appearance map {path}: "
            "unexpected shape (expected a top-level object with a 'calendars' dict)",
            file=sys.stderr,
        )
        return {}
    entries = data["calendars"]
    kept = {k: v for k, v in entries.items() if isinstance(v, dict)}
    dropped = sorted(k for k, v in entries.items() if not isinstance(v, dict))
    if dropped:
        print(
            f"[calendar_daemon] ignoring {len(dropped)} unusable map entries in "
            f"{path}: {', '.join(dropped[:5])}",
            file=sys.stderr,
        )
    return kept


def save_appearance_map(entries: dict) -> None:
    """Persist the id -> appearance map through the same atomic write.

    json.dumps' default `ensure_ascii=True` is deliberate here: the icons are
    Nerd Font private-use glyphs, and an ASCII payload is the one encoding a
    write cannot fail on whatever the daemon's locale happens to be. This file
    is machine-local cache state, not a config the operator reads, so the raw
    glyphs are worth less than a write that cannot raise UnicodeEncodeError.
    """
    payload = {
        "version": APPEARANCE_MAP_VERSION,
        "calendars": entries,
    }
    _write_json_atomic(_appearance_map_path(), json.dumps(payload, indent=2))


def resolve_appearance(cal_id, cal_name: str, mapping: dict):
    """(color, icon, source) for one calendar, in a fixed order.

    1. the persisted map, by id - the only branch a rename survives, because
       the id does not change when the name does;
    2. the repo defaults, by name - a fresh calendar being seeded;
    3. DEFAULT_COLOR/DEFAULT_ICON - nothing configured, counts as unmapped.

    Colour and icon are resolved independently, so a hand-written entry in the
    map can override one of them and still inherit the other from the defaults.
    """
    entry = mapping.get(cal_id) if cal_id else None
    mapped_color = entry.get("color") if isinstance(entry, dict) else None
    mapped_icon = entry.get("icon") if isinstance(entry, dict) else None
    color = mapped_color or CALENDAR_COLORS.get(cal_name)
    icon = mapped_icon or CALENDAR_ICONS.get(cal_name)

    from_map = [mapped_color is not None, mapped_icon is not None]
    if all(from_map):
        source = SOURCE_MAP
    elif not any(from_map) and color is None and icon is None:
        source = SOURCE_FALLBACK
    elif not any(from_map):
        source = SOURCE_DEFAULT
    else:
        source = SOURCE_MIXED
    return color or DEFAULT_COLOR, icon or DEFAULT_ICON, source


def resolve_calendar_appearances(calendars: list, mapping: dict):
    """Resolve every calendar and fold the result back into the map.

    Returns (resolved, mapping, changed). `resolved` is {calendar id:
    (color, icon, source)}; `changed` says whether `mapping` gained anything or
    had a recorded name refreshed, so the caller writes only when there is
    something to write.

    Two rules, and they are the whole point:

    * An id seen for the first time is seeded from the name-keyed defaults, so
      the repo tables reach the machine and every later rename is remembered.
    * An id already in the map keeps its recorded colour and icon and only has
      its `name` refreshed. That is what makes a rename free, and it is also
      why a manual override survives: nothing ever overwrites an entry's
      appearance once it exists.
    """
    resolved: dict = {}
    changed = False
    for cal in calendars or []:
        cal_id = cal.get("id")
        if not cal_id:
            # A calendar with no id cannot be keyed, matched or remembered, so
            # it is left out of the map entirely. Google always sends one; the
            # caller's lookup falls back for it, which also warns.
            continue
        cal_name = cal.get("summary", "Unknown")
        color, icon, source = resolve_appearance(cal_id, cal_name, mapping)
        resolved[cal_id] = (color, icon, source)

        entry = mapping.get(cal_id)
        if not isinstance(entry, dict):
            if source == SOURCE_FALLBACK:
                # Nothing was learned, so nothing is recorded. Persisting
                # DEFAULT_COLOR here would pin this calendar to the fallback
                # forever: branch 1 wins, so a colour added to CALENDAR_COLORS
                # in a later commit would never reach this machine.
                continue
            mapping[cal_id] = {"name": cal_name, "color": color, "icon": icon}
            changed = True
        elif entry.get("name") != cal_name:
            entry["name"] = cal_name
            changed = True
    return resolved, mapping, changed


def get_credentials():
    """Return valid Google API credentials or None if setup needed."""
    creds = None
    token_source = TOKEN_PATH if TOKEN_PATH.exists() else LEGACY_TOKEN_PATH
    if token_source.exists():
        try:
            creds = _google_credentials().from_authorized_user_file(str(token_source), SCOPES)
        except (OSError, ValueError, KeyError) as exc:
            # A truncated or hand-edited token.json used to raise straight out
            # of here, before any error handling. Treat it as "no token" and
            # say so, so the operator knows which file to delete.
            print(
                f"[calendar_daemon] ignoring unreadable token {token_source}: {exc}",
                file=sys.stderr,
            )
            creds = None
    if creds and creds.valid:
        if token_source != TOKEN_PATH:
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            TOKEN_PATH.write_text(creds.to_json())
        return creds
    if creds and creds.expired and creds.refresh_token:
        try:
            from google.auth.transport.requests import Request

            creds.refresh(Request())
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            TOKEN_PATH.write_text(creds.to_json())
            return creds
        except Exception as exc:
            print(f"[calendar_daemon] token refresh failed: {exc}", file=sys.stderr)
    if not CREDS_PATH.exists():
        return None
    if not sys.stdin.isatty():
        # This module is invoked by a Waybar `exec` poll with no TTY: the
        # prompt would be swallowed by whatever captures stdout and there would
        # be no way to answer it. Refuse instead of hanging, and say what to do.
        print(
            "[calendar_daemon] no TTY on stdin, so the interactive Google sign-in "
            "cannot run.\n"
            "  Run this once in a real terminal instead:\n"
            f"      {Path(sys.argv[0]).name if sys.argv and sys.argv[0] else 'calendar_daemon.py'} --init\n"
            "  To re-authorise, delete "
            f"{TOKEN_PATH} and run that command again.",
            file=sys.stderr,
        )
        return None
    from google_auth_oauthlib.flow import InstalledAppFlow

    flow = InstalledAppFlow.from_client_secrets_file(str(CREDS_PATH), SCOPES)
    flow.redirect_uri = "http://localhost"
    auth_url, _ = flow.authorization_url(access_type="offline", prompt="consent")
    print(f"\nOpen this URL in your browser:\n\n{auth_url}\n", file=sys.stderr)
    print("After clicking Allow, the browser will try to load http://localhost — that page", file=sys.stderr)
    print("will fail to load (that's expected). Copy the FULL URL from the address bar", file=sys.stderr)
    print("(it starts with http://localhost/?code=...) and paste it here:\n", file=sys.stderr)
    redirect_response = input("Paste the full redirect URL: ").strip()
    os.environ["OAUTHLIB_INSECURE_TRANSPORT"] = "1"
    flow.fetch_token(authorization_response=redirect_response)
    creds = flow.credentials
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    TOKEN_PATH.write_text(creds.to_json())
    return creds


def fetch_month(year: int, month: int) -> dict:
    """Fetch all Google Calendar events for the given month and write cache."""
    try:
        creds = get_credentials()
    except RuntimeError as exc:
        # e.g. the google client libraries are not installed. Report it the same
        # way as any other backend failure instead of raising, so the Waybar
        # module still gets its error payload.
        print(f"[calendar_daemon] calendar backend unavailable: {exc}", file=sys.stderr)
        return {
            "error": "google_client_missing",
            "events": [],
            "fetched_at": datetime.datetime.now().isoformat(),
            "month": f"{year:04d}-{month:02d}",
        }
    if creds is None:
        return {"error": "auth_required", "events": []}

    try:
        service = _build_service(creds)
        start, end = month_window(year, month)

        calendars = service.calendarList().list().execute().get("items", [])
        all_events = []
        unmapped = set()

        # Appearance is resolved by calendar id, not by name, so a rename on
        # Google's side keeps its colour instead of falling back to the
        # defaults. The map is seeded from the name-keyed repo tables the first
        # time an id is seen, so the tables still reach this machine.
        appearance_map = load_appearance_map()
        resolved, appearance_map, map_changed = resolve_calendar_appearances(
            calendars, appearance_map
        )

        for cal in calendars:
            cal_id = cal.get("id")
            cal_name = cal.get("summary", "Unknown")
            cal_color, cal_icon, source = resolved.get(
                cal_id, (DEFAULT_COLOR, DEFAULT_ICON, SOURCE_FALLBACK)
            )
            if source in (SOURCE_FALLBACK, SOURCE_MIXED):
                unmapped.add(cal_name)
            result = (
                service.events()
                .list(
                    calendarId=cal["id"],
                    timeMin=start.isoformat(),
                    timeMax=end.isoformat(),
                    singleEvents=True,
                    orderBy="startTime",
                )
                .execute()
            )
            for event in result.get("items", []):
                raw_start = event["start"].get("dateTime", event["start"].get("date", ""))
                all_day = "dateTime" not in event["start"]
                if all_day:
                    event_date = raw_start[:10]
                    start_time = "All day"
                    end_time = ""
                else:
                    dt = datetime.datetime.fromisoformat(raw_start)
                    event_date = dt.strftime("%Y-%m-%d")
                    start_time = dt.strftime("%H:%M")
                    raw_end = event.get("end", {}).get("dateTime", "")
                    end_time = (
                        datetime.datetime.fromisoformat(raw_end).strftime("%H:%M")
                        if raw_end
                        else ""
                    )
                all_events.append(
                    {
                        "date": event_date,
                        "start_time": start_time,
                        "end_time": end_time,
                        "title": event.get("summary", "(No title)"),
                        "calendar": cal_name,
                        "color": cal_color,
                        "icon": cal_icon,
                        "all_day": all_day,
                    }
                )

        if unmapped:
            # Either nothing is configured for this calendar at all, or the map
            # carries only half of its appearance (a hand-written colour with no
            # icon, say) and the other half fell through to the defaults. Both
            # are survivable, but neither may be silent: name them.
            print(
                "[calendar_daemon] no colour/icon configured for calendar(s): "
                + ", ".join(sorted(unmapped))
                + " (a calendar with no id, id mapping, or name in CALENDAR_COLORS/CALENDAR_ICONS)",
                file=sys.stderr,
            )

        if map_changed:
            # Written only when the map actually learned something, so the
            # read-modify-write window stays as small as it can. A lost update
            # from two concurrent polls costs one re-seed, never a crash.
            # Best-effort: a cache directory we cannot write is a reason to
            # lose the durable mapping, not a reason to lose the month.
            try:
                save_appearance_map(appearance_map)
            except OSError as exc:
                print(
                    f"[calendar_daemon] could not persist the calendar appearance "
                    f"map ({exc}); colours will fall back to name matching",
                    file=sys.stderr,
                )

        cache = {
            "fetched_at": datetime.datetime.now().isoformat(),
            "month": f"{year:04d}-{month:02d}",
            "events": all_events,
        }
        cache_path = CACHE_DIR / f"events_{year:04d}-{month:02d}.json"
        _write_json_atomic(cache_path, json.dumps(cache, indent=2))
        return cache
    except Exception as exc:
        print(f"[calendar_daemon] fetch failed: {exc}", file=sys.stderr)
        return {"error": "fetch_failed", "events": [], "fetched_at": datetime.datetime.now().isoformat(), "month": f"{year:04d}-{month:02d}"}


def load_month(year: int, month: int) -> dict:
    """Load month from cache, fetching if missing or older than CACHE_TTL_HOURS."""
    cache_path = CACHE_DIR / f"events_{year:04d}-{month:02d}.json"
    if cache_path.exists():
        try:
            data = json.loads(cache_path.read_text())
            age = datetime.datetime.now() - datetime.datetime.fromisoformat(data["fetched_at"])
        except (OSError, ValueError, KeyError, TypeError) as exc:
            # A corrupt cache used to raise an uncaught JSONDecodeError, which
            # in a Waybar `exec` poll means a blank module nobody can debug.
            # Treat it as a miss and refetch.
            print(
                f"[calendar_daemon] ignoring unreadable cache {cache_path}: {exc}",
                file=sys.stderr,
            )
        else:
            if age.total_seconds() < CACHE_TTL_HOURS * 3600:
                return data
    return fetch_month(year, month)


def build_days_grid(year: int, month: int, events: list, today: str | None = None) -> list:
    """Build a 7-column Mon-Sun grid of day cells with event dots."""
    if today is None:
        today = datetime.date.today().strftime("%Y-%m-%d")
    by_date: dict[str, list] = {}
    for event in events:
        by_date.setdefault(event["date"], []).append(event)

    cal = calendar.Calendar(firstweekday=0)
    days = []
    for dt in cal.itermonthdates(year, month):
        date_str = dt.strftime("%Y-%m-%d")
        day_events = by_date.get(date_str, [])
        seen_colors: set[str] = set()
        seen_icons: list[dict] = []
        for e in day_events:
            if e["color"] not in seen_colors:
                seen_colors.add(e["color"])
                seen_icons.append({
                    # The event's own icon, already resolved at fetch time against
                    # the stable calendar id. Re-deriving it from the display name
                    # here is how a renamed calendar lost its icon on the day grid:
                    # the stored icon was right and this threw it away. For every
                    # case where the name is still in CALENDAR_ICONS the stored
                    # value is identical to the name lookup, so this changes nothing
                    # there - and it cannot consult a table that is keyed on
                    # something renameable.
                    # `or` rather than get(key, default): a cache entry with an
                    # explicit null icon should fall back too, which the old
                    # name lookup did implicitly by recomputing.
                    "icon": e.get("icon") or DEFAULT_ICON,
                    "color": e["color"],
                })
        icons = seen_icons[:2]
        days.append(
            {
                "date": date_str,
                "date_num": str(dt.day),
                "in_month": dt.month == month,
                "is_today": date_str == today,
                "icons": icons,
                "overflow": max(0, len(seen_icons) - 2),
                "events": day_events,
            }
        )
    return days


def _month_label(year: int, month: int) -> str:
    return datetime.date(year, month, 1).strftime("%B %Y")


def _day_label(date_str: str) -> str:
    # strftime("%-d") is a GNU extension and prints a literal "%-d" on
    # musl/busybox, so the day number is formatted explicitly.
    dt = datetime.date.fromisoformat(date_str)
    return f"{dt:%A, %B} {dt.day}"


def load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text())
        except (OSError, ValueError) as exc:
            # Same failure mode as the month cache: rebuild from today instead
            # of crashing the process that was launched to fix the calendar.
            print(
                f"[calendar_daemon] ignoring unreadable state {STATE_PATH}: {exc}",
                file=sys.stderr,
            )
    today = datetime.date.today()
    return {
        "current_month": today.strftime("%Y-%m"),
        "selected_day": today.strftime("%Y-%m-%d"),
    }


def write_state(year: int, month: int, selected_day: str) -> None:
    """Fetch/load month, build days grid, write state.json."""
    month_data = load_month(year, month)
    error = month_data.get("error")
    events = month_data.get("events", [])
    days = build_days_grid(year, month, events)
    weeks = [days[i:i + 7] for i in range(0, len(days), 7)]

    selected_events = []
    for e in events:
        if e["date"] == selected_day:
            ev = dict(e)
            if "icon" not in ev:
                ev["icon"] = CALENDAR_ICONS.get(ev.get("calendar", ""), DEFAULT_ICON)
            selected_events.append(ev)

    state = {
        "current_month": f"{year:04d}-{month:02d}",
        "month_label": _month_label(year, month),
        "selected_day": selected_day,
        "selected_day_label": _day_label(selected_day),
        "selected_events": selected_events,
        "loading": False,
        "stale": False,
        "error": error,
        "days": days,
        "weeks": weeks,
    }
    _write_json_atomic(STATE_PATH, json.dumps(state))


def action_init() -> None:
    today = datetime.date.today()
    write_state(today.year, today.month, today.strftime("%Y-%m-%d"))


def _carry_selected_day(state: dict, year: int, month: int) -> str:
    raw = state.get("selected_day", datetime.date.today().strftime("%Y-%m-%d"))
    try:
        old = datetime.date.fromisoformat(raw)
    except (TypeError, ValueError) as exc:
        # Narrowed from a bare `except`: only an unparseable selected_day lands
        # here, and the fallback is now announced instead of silent.
        print(
            f"[calendar_daemon] unreadable selected_day {raw!r} ({exc}); "
            f"falling back to {year:04d}-{month:02d}-01",
            file=sys.stderr,
        )
        return datetime.date(year, month, 1).strftime("%Y-%m-%d")
    day = min(old.day, calendar.monthrange(year, month)[1])
    return datetime.date(year, month, day).strftime("%Y-%m-%d")


def action_prev() -> None:
    state = load_state()
    ym = state.get("current_month", datetime.date.today().strftime("%Y-%m"))
    year, month = int(ym[:4]), int(ym[5:7])
    month -= 1
    if month == 0:
        month, year = 12, year - 1
    write_state(year, month, _carry_selected_day(state, year, month))


def action_next() -> None:
    state = load_state()
    ym = state.get("current_month", datetime.date.today().strftime("%Y-%m"))
    year, month = int(ym[:4]), int(ym[5:7])
    month += 1
    if month == 13:
        month, year = 1, year + 1
    write_state(year, month, _carry_selected_day(state, year, month))


def action_select(date_str: str) -> None:
    year, month = int(date_str[:4]), int(date_str[5:7])
    current_month = f"{year:04d}-{month:02d}"
    state = load_state()

    if state.get("current_month") == current_month and state.get("weeks"):
        selected_events = []
        for week in state["weeks"]:
            for day in week:
                if day["date"] == date_str:
                    selected_events = list(day.get("events", []))
                    break
        for ev in selected_events:
            if "icon" not in ev:
                ev["icon"] = CALENDAR_ICONS.get(ev.get("calendar", ""), DEFAULT_ICON)
        state["selected_day"] = date_str
        state["selected_day_label"] = _day_label(date_str)
        state["selected_events"] = selected_events
        _write_json_atomic(STATE_PATH, json.dumps(state))
        return

    write_state(year, month, date_str)


def main() -> None:
    parser = argparse.ArgumentParser(description="Warmind Waybar calendar state daemon")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--init", action="store_true", help="Initialize to today")
    group.add_argument("--prev", action="store_true", help="Go to previous month")
    group.add_argument("--next", action="store_true", help="Go to next month")
    group.add_argument("--select", metavar="YYYY-MM-DD", help="Select a specific day")
    args = parser.parse_args()

    if args.init:
        action_init()
    elif args.prev:
        action_prev()
    elif args.next:
        action_next()
    elif args.select:
        action_select(args.select)


if __name__ == "__main__":
    main()

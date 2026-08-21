#!/usr/bin/env python3
"""Waybar custom-module data source for Dropbox.

Port of Omarchy Quattro's shell/plugins/panels/dropbox helper (status.py +
Model.js) to a waybar custom module: daemon state, plan usage and recent files.
"""
import html
import json
import os
import shutil
import subprocess
from pathlib import Path


# Nerd Font codepoints (nf-md-*), written as escapes so they survive any editor.
DROPBOX_GLYPH = "\U000F01E3"  # nf-md-dropbox

PLAN_QUOTAS = {
    "basic": 2_000_000_000,
    "plus": 2_000_000_000_000,
    "pro": 3_000_000_000_000,
    "professional": 3_000_000_000_000,
    "essentials": 3_000_000_000_000,
}

# Real quota for this machine: Basic plan plus referral/promo bonuses.
# Neither ~/.dropbox/info.json nor dropbox-cli expose the real quota, so pin it.
QUOTA_OVERRIDE_BYTES = 12_250_000_000


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def command_output(command: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=4,
        )
    except (OSError, subprocess.TimeoutExpired):
        return -1, ""
    return completed.returncode, (completed.stdout + completed.stderr).strip()


def account_info() -> dict:
    try:
        with (Path.home() / ".dropbox" / "info.json").open(encoding="utf-8") as handle:
            info = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}
    for account_type in ("personal", "business"):
        account = info.get(account_type)
        if isinstance(account, dict):
            return account
    return {}


def format_bytes(size: float) -> str:
    value = float(size)
    if value <= 0:
        return "0 B"
    units = ["B", "KB", "MB", "GB", "TB"]
    index = 0
    while value >= 1000 and index < len(units) - 1:
        value /= 1000
        index += 1
    decimals = 0 if value >= 100 or index == 0 else 2
    text = f"{value:.{decimals}f}".rstrip("0").rstrip(".")
    return f"{text} {units[index]}"


def total_bytes(path: str) -> int:
    """Total bytes on disk under the Dropbox folder."""
    total = 0
    try:
        for root, dirs, files in os.walk(path):
            dirs[:] = [n for n in dirs if not os.path.islink(os.path.join(root, n))]
            for name in files:
                file_path = os.path.join(root, name)
                if os.path.islink(file_path):
                    continue
                try:
                    total += os.stat(file_path).st_size
                except OSError:
                    continue
    except OSError:
        return 0
    return total


def build_tooltip(state: str, status_text: str, directory: str,
                  used: int, quota: int, quota_known: bool) -> str:
    esc = html.escape
    headline = {
        "stopped": "Syncing paused",
        "login": "Login required",
        "unavailable": "Dropbox CLI is not installed",
    }.get(state, esc(status_text) or "Up to date")

    lines = [f"<b>{DROPBOX_GLYPH} Dropbox</b> · {headline}"]
    if state == "active" and directory:
        if quota_known and quota > 0:
            percent = used / quota * 100
            lines.append(f"Stored: {format_bytes(used)} of {format_bytes(quota)} ({percent:.0f}%)")
        else:
            lines.append(f"Stored: {format_bytes(used)}")
    return "\n".join(lines)


def status_payload() -> dict:
    cli = shutil.which("dropbox-cli")
    account = account_info()
    directory = account.get("path") if isinstance(account.get("path"), str) else ""
    plan = account.get("subscription_type") if isinstance(account.get("subscription_type"), str) else ""
    authenticated = bool(directory) and Path(directory).is_dir()

    used, quota, quota_known = 0, 0, False
    if cli:
        # dropbox-cli running exits 1 when running and 0 when not (inverted!),
        # so the ps check is the source of truth and the CLI is a fallback.
        _, running_output = command_output(["ps", "-C", "dropbox", "-o", "pid="])
        running = any(line.strip().isdigit() for line in running_output.splitlines())
        if not running:
            cli_exit, _ = command_output([cli, "running"])
            running = cli_exit == 1
        status_exit, status_output = command_output([cli, "status"])
        lowered = status_output.lower()
        stopped_words = ("isn't running" in lowered or "not running" in lowered
                         or lowered == "stopped")
        if not running:
            state = "stopped"
            status_text = "Stopped"
        elif stopped_words or not status_output:
            # Process exists but dropbox-cli hasn't caught up yet (startup race).
            state = "active"
            status_text = "Starting…"
        else:
            state = "active"
            status_text = status_output
        if authenticated:
            quota = QUOTA_OVERRIDE_BYTES or PLAN_QUOTAS.get(plan.lower(), 0)
            used = total_bytes(directory)
            # Bonus/referral space can exceed the plan's base quota; don't
            # report a misleading >100% usage in that case.
            quota_known = quota > 0 and used <= quota
    else:
        state = "unavailable"
        status_text = "Dropbox CLI is not installed"

    if cli and not authenticated:
        state = "login"
        status_text = "Login required"

    return {
        "text": f"<span font_desc='JetBrainsMono Nerd Font 16'>{DROPBOX_GLYPH}</span> ",
        "alt": status_text,
        "class": f"dropbox-{state}",
        "tooltip": build_tooltip(state, status_text, directory,
                                 used, quota, quota_known),
    }


if __name__ == "__main__":
    emit(status_payload())

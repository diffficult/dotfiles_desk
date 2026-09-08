#!/usr/bin/env python3
import json
import shutil
import subprocess
from pathlib import Path


DROPBOX_GLYPH = "󰇣"


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def command_output(command: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=3,
        )
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""
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


def daemon_running() -> bool:
    exit_code, output = command_output(["ps", "-C", "dropbox", "-o", "pid="])
    return exit_code == 0 and any(line.strip().isdigit() for line in output.splitlines())


def status_payload() -> dict:
    cli = shutil.which("dropbox-cli")
    account = account_info()
    directory = account.get("path") if isinstance(account.get("path"), str) else ""
    authenticated = bool(directory)
    directory_available = bool(directory) and Path(directory).is_dir()

    if not cli:
        state = "unavailable"
        status = "Dropbox CLI is not installed"
    else:
        running_exit, _ = command_output([cli, "running"])
        running = running_exit == 0 or daemon_running()
        if not running:
            state = "stopped"
            status = "Stopped"
        else:
            _, status_output = command_output([cli, "status"])
            state = "active"
            lowered = status_output.lower()
            status = (
                "Running"
                if not status_output
                or "isn't running" in lowered
                or "not running" in lowered
                or lowered == "stopped"
                else status_output
            )

    if cli and not authenticated:
        state = "login"
        status = "Login required"

    if cli and authenticated and not directory_available:
        state = "login"
        status = "Dropbox folder unavailable"

    tooltip = f"Dropbox: {status}"
    if directory:
        tooltip += f"\nFolder: {directory}"

    return {
        "text": f"<span font_desc='JetBrainsMono Nerd Font 16'>{DROPBOX_GLYPH}</span> ",
        "alt": status,
        "class": f"dropbox-{state}",
        "tooltip": tooltip,
    }


if __name__ == "__main__":
    emit(status_payload())

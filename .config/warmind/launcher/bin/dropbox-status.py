#!/usr/bin/env python3

import heapq
import json
import os
import re
import shutil
import subprocess
from pathlib import Path


# The Dropbox client exposes no quota: info.json carries only the folder and the
# subscription name, dropbox-cli has no size command, and the daemon's own
# databases are opaque. Account capacity lives in the web UI / API only, so the
# user keeps it in one live file next to the launcher tree (deploy never purges
# it). Units are decimal, matching how Dropbox reports storage.
QUOTA_UNITS = {"B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}
QUOTA_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB)?", re.IGNORECASE)


def quota_path():
    return Path.home() / ".config" / "warmind" / "dropbox-quota"


def read_quota():
    try:
        text = quota_path().read_text(encoding="utf-8")
    except OSError:
        return 0

    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        match = QUOTA_RE.fullmatch(line)
        if not match:
            continue
        value = float(match.group(1))
        unit = (match.group(2) or "GB").upper()
        return int(value * QUOTA_UNITS[unit])
    return 0


def account_info():
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


def command_output(command):
    try:
        completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=4)
    except (OSError, subprocess.TimeoutExpired):
        return 1, ""
    return completed.returncode, (completed.stdout + completed.stderr).strip()


def daemon_running():
    exit_code, output = command_output(["ps", "-C", "dropbox", "-o", "pid="])
    return exit_code == 0 and any(line.strip().isdigit() for line in output.splitlines())


def scan_recent(directory, limit=25):
    total = 0
    counter = 0
    recent = []
    try:
        for root, dirs, files in os.walk(directory):
            dirs[:] = [name for name in dirs if not os.path.islink(os.path.join(root, name))]
            for name in files:
                path = os.path.join(root, name)
                if os.path.islink(path):
                    continue
                try:
                    stat = os.stat(path)
                except OSError:
                    continue
                total += stat.st_size
                relative = os.path.relpath(path, directory)
                folder = os.path.dirname(relative)
                row = {
                    "name": name,
                    "path": path,
                    "folder": "/" if folder in ("", ".") else folder,
                    "modifiedTs": int(stat.st_mtime),
                }
                counter += 1
                entry = (row["modifiedTs"], counter, row)
                if len(recent) < limit:
                    heapq.heappush(recent, entry)
                else:
                    heapq.heappushpop(recent, entry)
    except OSError:
        return 0, []
    return total, [entry[2] for entry in sorted(recent, reverse=True)]


def main():
    cli = shutil.which("dropbox-cli")
    account = account_info()
    directory = account.get("path") if isinstance(account.get("path"), str) else ""
    plan = account.get("subscription_type") if isinstance(account.get("subscription_type"), str) else ""
    directory_available = bool(directory) and Path(directory).is_dir()
    running = False
    status_text = "Dropbox CLI is not installed"

    if cli:
        running_exit, _ = command_output([cli, "running"])
        running = running_exit == 0 or daemon_running()
        status_exit, status_output = command_output([cli, "status"])
        lowered_status = status_output.lower()
        status_is_stopped = (
            "isn't running" in lowered_status
            or "not running" in lowered_status
            or lowered_status == "stopped"
        )
        if running and status_exit == 0 and status_output and not status_is_stopped:
            status_text = status_output
        elif running:
            status_text = "Running"
        else:
            status_text = "Stopped"

    used_bytes, files = scan_recent(directory) if directory_available else (0, [])
    quota_bytes = read_quota()
    print(json.dumps({
        "installed": cli is not None,
        "running": running,
        "authenticated": bool(directory),
        "directory": directory,
        "directoryAvailable": directory_available,
        "plan": plan,
        "statusText": status_text,
        "usedBytes": used_bytes,
        "quotaBytes": quota_bytes,
        "files": files,
    }))


if __name__ == "__main__":
    main()

# Hyprland Config Documentation

This directory contains documentation of solved issues, configuration decisions, and methods
used to maintain this Hyprland setup. Each issue gets its own markdown file.

## Purpose

When issues are debugged and solved, Claude documents them here so that:
- Future regressions can be diagnosed faster by referencing known causes
- The reasoning behind non-obvious config choices is preserved
- External links and sources are kept for follow-up research

## Structure

Each issue document covers:
- **Symptoms** — what the user observed
- **Root causes** — what was actually broken and why
- **Files modified** — exact paths of every changed file
- **Fix applied** — what changes were made
- **Why it regressed** — what upstream change triggered the issue
- **Sources** — links to GitHub issues, wiki pages, etc.

## Issue Index

| File | Summary | Date |
|------|---------|------|
| [001-dpms-nvidia-wakeup-regression.md](001-dpms-nvidia-wakeup-regression.md) | Monitors not waking from DPMS after Hyprland 0.54 update (NVIDIA RTX 4060) | 2026-02-28 |
| [002-warmind-qml-hyprland-lua-ipc.md](002-warmind-qml-hyprland-lua-ipc.md) | Warmind QML still uses legacy `hyprctl dispatch`; broken under Hyprland Lua manager — refactor checklist | 2026-07-31 |
| [scrolloverview-recovery.md](scrolloverview-recovery.md) | Hyprland 0.57 broke the scrolloverview plugin ABI; agent runbook to rebuild the local fallback and migrate back to `hyprpm` `origin/new-release` | 2026-10-28 |
| [hyprland-lua-migration.md](hyprland-lua-migration.md) | Full Hyprland 0.55+ Lua migration playbook, waybar shim, deprecated scripts | 2026-07-29 |

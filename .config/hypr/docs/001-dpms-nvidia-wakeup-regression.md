# 001 — Monitors Not Waking from DPMS After Hyprland 0.54 (NVIDIA)

**Date:** 2026-02-28
**Hyprland version at time of regression:** 0.54.0-1
**GPU:** NVIDIA RTX 4060 (AD107)
**Monitors:** DP-1, DP-2 (dual 2560x1440@59.95)

---

## Symptoms

After updating Hyprland to 0.54, monitors that entered DPMS power-off state via hypridle
would not wake up when the user pressed a key or moved the mouse. The setup had previously
been working and was fixed once before — the 0.54 update caused a regression.

---

## Root Causes

Three separate issues combined to cause this:

### 1. `key_press_enables_dpms` and `mouse_move_enables_dpms` default to `false`

These two options in the `misc {}` section of `hyprland.conf` control whether Hyprland
itself wakes monitors on input. Both default to `false`. When not explicitly set, Hyprland
relies entirely on hypridle's `on-resume` callback to turn monitors back on.

If `on-resume` fails for any reason (see cause 2), nothing wakes the display.

### 2. NVIDIA + `hyprctl dispatch dpms off` = monitor disconnect, not standby

`hyprctl dispatch dpms` is a DRM-level hack, not a proper Wayland protocol call. With
NVIDIA GPUs (RTX 4060 in this case), the driver can interpret the DRM DPMS signal as a
physical monitor disconnect rather than a standby request. When this happens:

- The monitor goes dark but is no longer tracked as connected
- hypridle's `on-resume` either doesn't fire or fires but `dpms on` fails on the
  "disconnected" display
- Users are stuck with a black screen; the session is still running but not visible

This is a known issue documented across many Hyprland GitHub reports. The fix is to use
`wlopm` instead, which uses the proper `wlr-output-power-management-v1` Wayland protocol
and communicates with the compositor correctly rather than going through DRM directly.

### 3. `hypridle-switch.sh` silently failed to restart hypridle (SIGUSR1 bug)

`hypridle-switch.sh` (the script behind `hypridle-switch.timer`) attempted to reload
hypridle config using `SIGUSR1`:

```bash
pkill -SIGUSR1 hypridle 2>/dev/null || {
    pkill hypridle
    sleep 0.5
    hypridle &   # also wrong: missing uwsm, wrong environment
}
```

The problem: `pkill -SIGUSR1` exits **0** as long as the process exists and the signal
was delivered — regardless of whether hypridle actually handles the signal. hypridle does
**not** support `SIGUSR1` for config reload. Since the command exits 0, the `||` fallback
never runs. The symlink switches but hypridle keeps the old config in memory.

On login, this caused hypridle to either run with the wrong config or not run at all
(if the timer fired and killed it before exec-once had a chance to start it).

Additionally, the fallback used plain `hypridle &` instead of `uwsm app -- hypridle`,
which may lack the Wayland session environment needed for hypridle to connect.

**Fix — `hypridle-switch.sh`:**

```bash
# Before (broken)
if pgrep -x hypridle > /dev/null; then
    pkill -SIGUSR1 hypridle 2>/dev/null || {
        pkill hypridle
        sleep 0.5
        hypridle &
    }
fi

# After (fixed)
pkill hypridle 2>/dev/null
sleep 0.5
uwsm app -- hypridle &
```

Always kill and restart unconditionally. No SIGUSR1, no pgrep check, always uwsm.

### 4. Hyprland 0.54 refactored the internal event bus

The 0.54 release refactored Hyprland's event system into a "typed event bus". This changed
how internal events (including input activity events) are processed. hypridle hooks into
Hyprland's idle notification via the `ext-idle-notify-v1` Wayland protocol. The event bus
refactoring appears to have made the already-borderline `hyprctl dispatch dpms` path less
reliable for NVIDIA, causing `on-resume` to either not trigger or fail silently in cases
that previously worked.

---

## Why It Regressed in 0.54 Specifically

The previous fix had addressed the `hyprctl dispatch dpms on` conflict (from lock screen
scripts), but left two latent issues in place:

1. `key_press_enables_dpms` was never explicitly set to `true` — it was always `false` by
   default, but hypridle's `on-resume` was covering for it.
2. `hyprctl dispatch dpms` was still being used — NVIDIA had been tolerating it, but the
   event bus refactoring in 0.54 made the race condition / protocol mismatch more likely to
   manifest.

---

## Files Modified

| File | Change |
|------|--------|
| `/home/rx/.config/hypr/general.conf` | Added `key_press_enables_dpms = true` and `mouse_move_enables_dpms = true` to `misc {}` |
| `/home/rx/.config/hypr/hypridle-night.conf` | Replaced `hyprctl dispatch dpms off` with `wlopm --off '*'` |
| `/home/rx/.config/hypr/hypridle-day.conf` | Replaced all `hyprctl dispatch dpms off/on` with `wlopm --off/on '*'` (including `before_sleep_cmd` / `after_sleep_cmd`) |
| `/home/rx/.config/hypr/hypridle-quicktest.conf` | Replaced `hyprctl dispatch dpms off` with `wlopm --off '*'` |
| `/home/rx/.config/hypr/hypridle-test.conf` | Replaced `hyprctl dispatch dpms off` with `wlopm --off '*'` |
| `/home/rx/.local/bin/hypr_scripts/aerial-dpms-resume.sh` | Replaced `hyprctl dispatch dpms on` with `wlopm --on '*'` |
| `/home/rx/.config/hypr/keybindings.conf` | Updated CTRL+ALT+F1 emergency keybind from `hyprctl dispatch dpms on` to `wlopm --on '*'` |
| `/home/rx/.config/hypr/hypridle-fulltest.conf` | New file — full path test config (15s lock → 30s DPMS) for verifying lock+DPMS together |
| `/home/rx/.local/bin/hypr_scripts/hypridle-switch.sh` | Removed broken SIGUSR1 reload attempt; now always kills and restarts with `uwsm app -- hypridle` |

---

## Fix Applied

### Step 1 — Install `wlopm`

```bash
sudo pacman -S wlopm
```

`wlopm` (Wayland Output Power Manager) uses the `wlr-output-power-management-v1` protocol,
which is the correct Wayland-native way to control display power states. Unlike
`hyprctl dispatch dpms`, it does not go through DRM directly and does not confuse NVIDIA
drivers into treating the monitor as disconnected.

### Step 2 — Reload Hyprland config

```bash
hyprctl reload
```

### Step 3 — Config changes (already applied)

**`general.conf` — `misc {}` section:**
```conf
misc {
    key_press_enables_dpms = true    # Was missing (default: false)
    mouse_move_enables_dpms = true   # Was missing (default: false)
}
```

**All `hypridle-*.conf` files — listener block:**
```conf
# Before
on-timeout = hyprctl dispatch dpms off
on-resume = ...

# After
on-timeout = wlopm --off '*'
on-resume = ...
```

**`aerial-dpms-resume.sh` — monitor wake line:**
```bash
# Before
hyprctl dispatch dpms on

# After
wlopm --on '*'
```

---

## How the Fix Works

- **`key_press_enables_dpms = true`** — Hyprland itself now wakes monitors on any keypress,
  independently of whether hypridle's `on-resume` fires. This is the primary safety net.
- **`mouse_move_enables_dpms = true`** — Same but for mouse movement.
- **`wlopm --off '*'`** — Powers off all outputs using the Wayland protocol. NVIDIA handles
  this correctly (power-saving standby rather than disconnect). The `'*'` pattern targets
  all connected outputs, fixing the multi-monitor inconsistency where `hyprctl dispatch dpms`
  sometimes only turned off one monitor.
- **`wlopm --on '*'`** — Powers all outputs back on. Called from hypridle's `on-resume`
  (via `aerial-dpms-resume.sh`) when activity is detected.

---

## Gotcha: `hypridle-switch.timer` Overrides Manual Symlink Changes

This setup uses a systemd user timer to auto-switch between day/night hypridle configs:

```bash
systemctl --user status hypridle-switch.timer
# Fires at 9am and 10pm, switching hypridle.conf symlink based on time of day
```

The timer runs `hypridle-switch.service` which calls `~/.local/bin/hypr_scripts/hypridle-switch.sh`.
That script **overwrites the symlink** to match the current time of day.

**Consequence:** If you manually switch the symlink to a test config (e.g. `hypridle-quicktest.conf`)
before a reboot, the timer fires during login and reverts it. The test config appears to not work
when in fact the wrong config was loaded.

**Workaround for testing:** After setting the symlink manually, always kill and restart hypridle
explicitly — don't rely on the reboot to pick it up:

```bash
ln -sf ~/.config/hypr/hypridle-quicktest.conf ~/.config/hypr/hypridle.conf
pkill hypridle
uwsm app -- hypridle &
# Verify it loaded the right config from the LOG output
```

Also note: `hypridle-switch.service` showed as `failed` on login. The root cause is that
`pkill -SIGUSR1 hypridle` exits **0** (signal successfully delivered) even though hypridle
ignores `SIGUSR1` entirely — it doesn't support config reload via signal. Because the
command exits 0, the `||` fallback (kill + restart) never runs. hypridle keeps the old
config in memory even though the symlink changed.

**Fix applied to `hypridle-switch.sh`:** Removed the SIGUSR1 attempt entirely. The script
now always does a clean kill + `uwsm app -- hypridle` restart whenever a config switch is
needed. Plain `hypridle &` was also replaced with `uwsm app -- hypridle &` to ensure the
process gets the correct Wayland session environment.

---

## Verification (Tested)

**Test 1 — DPMS only (quicktest, 30s timeout, no lock screen):**

Confirmed working on 2026-03-01:

1. Idle 30s → both DP-1 and DP-2 went dark via `wlopm --off '*'` ✓
2. Pressed a key → both monitors woke immediately ✓
3. Moved mouse → both monitors woke immediately ✓

**Test 2 — Full path (fulltest config: 15s lock → 30s DPMS):**

Confirmed working on 2026-03-01 after fixing `hypridle-switch.sh`:

1. Idle 15s → lock screen (aerial-hyprlock.sh + mpvpaper) activated ✓
2. Idle 30s → both monitors went dark via `wlopm --off '*'` while locked ✓
3. Pressed a key → both monitors woke, lock screen still shown ✓
4. Moved mouse → both monitors woke, lock screen still shown ✓

Test config used:
```conf
# ~/.config/hypr/hypridle-fulltest.conf
listener {
    timeout = 15
    on-timeout = ~/.local/bin/hypr_scripts/aerial-hyprlock.sh
}
listener {
    timeout = 30
    on-timeout = wlopm --off '*'
    on-resume = ~/.local/bin/hypr_scripts/aerial-dpms-resume.sh
}
```

---

## Sources

- [Hyprland Discussion #11356 — `dpms off` causes monitor to disconnect after ~5 minutes](https://github.com/hyprwm/Hyprland/discussions/11356)
- [Hyprland Discussion #11836 — How to handle DPMS off issues on AMD GPUs (monitor disable workaround)](https://github.com/hyprwm/Hyprland/discussions/11836)
- [Hypridle Issue #145 — Black screen / failure to wake up (key_press_enables_dpms workaround)](https://github.com/hyprwm/hypridle/issues/145)
- [Hyprland Issue #8357 — Cannot wake up monitor after dpms off](https://github.com/hyprwm/Hyprland/issues/8357)
- [Hyprland Discussion #11230 — `dispatch dpms off` regularly misses monitors in multi-monitor setup](https://github.com/hyprwm/Hyprland/discussions/11230)
- [Hyprland Issue #5752 — After DPMS on, destroys monitor before it can wake from energy saving](https://github.com/hyprwm/Hyprland/issues/5752)
- [Hyprland 0.54.0 Release Notes](https://hypr.land/news/update54/)

---

## Issue: hyprlock SIGSEGV After Config Switch (Cascading Lock Crash)

**Date discovered:** 2026-03-08
**Pattern:** hyprlock crashes every day at 09:15 and 22:10 — exactly at idle lock timeout after config switch

### Root Cause

`hypridle-switch.sh` called `wlopm --on '*'` unconditionally after restarting hypridle.
When hyprlock was already running (session locked, monitors off from DPMS), calling
`wlopm --on '*'` caused Hyprland to reinitialize lock surfaces for the newly-powered
outputs. This crashed hyprlock mid-operation, leaving the Wayland session lock in a stuck
"locked" state with no hyprlock process holding it.

Cascade:
1. Config switch fires (9am or 10pm)
2. `wlopm --on '*'` runs while hyprlock holds session lock → **hyprlock crashes**
3. `aerial-hyprlock.sh` cleanup removes `LOCK_FILE`
4. Session lock state stuck in Wayland (crash = no clean release)
5. Idle timeout fires, new `aerial-hyprlock.sh` runs, `LOCK_FILE` gone → proceeds
6. New hyprlock tries to grab session lock → compositor sends `finished` immediately ("yeeted")
7. New hyprlock also crashes (`SIGSEGV` in `onLockFinished`)
8. Stuck session lock persists → user locked out permanently

**`session_lock_xray = true` was NOT the cause** — disabling it made the lock screen
background black (it's what lets hyprlock see through to mpvpaper) without fixing anything.

### Fix — `hypridle-switch.sh`

```bash
# Before (crashes hyprlock if session is locked)
wlopm --on '*'

# After (safe)
if ! pgrep -x hyprlock > /dev/null; then
    wlopm --on '*'
fi
```

Only wake monitors if hyprlock is not running. If the session is locked, hyprlock
manages its own surfaces — interfering with `wlopm` causes it to crash.

### Safety Net Already In Place

`allow_session_lock_restore = true` in `misc {}` allows recovery when hyprlock dies:
```bash
hyprctl keyword misc:allow_session_lock_restore 1
```
This unblocks the stuck session so the user can get back in, but does not prevent the
crash. The `pgrep` guard in the switch script is the actual prevention.

### Files Modified

| File | Change |
|------|--------|
| `/home/rx/.local/bin/hypr_scripts/hypridle-switch.sh` | Guard `wlopm --on` with `pgrep -x hyprlock` check |
| `/home/rx/.config/hypr/general.conf` | Restored `session_lock_xray = true` (was incorrectly disabled) |

---

## Issue: Monitors Stuck Off After hypridle `on-resume` Is Orphaned (2026-10-24)

**Symptom:** Machine fully awake (SSH works, no `PM: suspend`/`PM: resume` events in the
journal), both outputs report `connected` but `dpms=Off`, and key presses / pointer motion
do nothing. `wlopm --on '*'` restores both displays instantly.

**Root cause — two independent bugs:**

1. **hypridle drops the long listener's `on-resume`.** `CHypridle::onInhibit()` destroys
   and recreates every `ext-idle-notify` object whenever the idle-inhibitor count drops
   to 0 while idled (any app releasing "Playing video" / Steam wake lock). The recreated
   notification starts its timeout over, so it never emits `resumed`, and `on-resume`
   never runs even though the outputs are off. Evidence: `Inhibit locks: 0` at 21:11:37
   and 21:29:48, the lock rule firing exactly 900s later (21:26:37) instead of
   immediately, and zero `Resumed:` lines for the entire boot.
2. **Hyprland's built-in wake is inert with `wlopm`.** `misc:key_press_enables_dpms` and
   `misc:mouse_move_enables_dpms` only fire when `m_dpmsStateOn == false`
   (`InputManager.cpp`, `PointerManager.cpp`). `wlopm`'s
   `wlr-output-power-management-v1` path calls `CMonitor::setDPMS()` directly and never
   updates that flag, which stays at its default `true`. The safety net was therefore
   dead the whole time.

**Fix:** after `wlopm --off '*'`, clear Hyprland's flag with a DPMS dispatch:

```conf
on-timeout = wlopm --off '*' && hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
```

`Actions::dpms(DISABLE)` calls `setDPMS(false)`, which early-returns because the outputs
are already off (no DRM traffic, no NVIDIA disconnect risk), then sets
`m_dpmsStateOn = false`. The next key press or pointer move runs `Actions::dpms(ENABLE)`,
sets the flag back to `true`, and powers the outputs on — independently of hypridle's
`on-resume`, which is kept only for the mpvpaper restart.

**Gotcha:** Hyprland 0.56 parses `hyprctl dispatch ...` as a Lua expression; the legacy
`hyprctl dispatch dpms off` fails with `'hl.dispatch(dpms off)' syntax error`. Use
`hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`.

**Verified 2026-10-24:** with `wlopm --off '*' && hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`,
both a synthetic key press (ydotool) and a synthetic pointer move brought DP-1 and DP-2
back (`dpmsStatus: true`) on NVIDIA 615.78 / Hyprland 0.56.2.

| File | Change |
|------|--------|
| `~/.config/hypr/hypridle-day.conf` | `on-timeout` clears `dpmsStateOn` after `wlopm --off` |
| `~/.config/hypr/hypridle-night.conf` | Same |

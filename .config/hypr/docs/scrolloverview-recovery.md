# ScrollOverview recovery and return to hyprpm

Agent runbook. Written 2026-10-28 for this machine (`rx`, Hyprland 0.57.0).
Read the whole file before changing anything. Verify the state below instead of
trusting it blindly; a later session may already have migrated back to hyprpm.

## Current state

| Item | Value |
|---|---|
| Hyprland | 0.57.0, commit `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426` |
| Config entrypoint | `~/.config/hypr/hyprland.lua` |
| Plugin config/binds | `~/.config/hypr/lua/integrations/scrolloverview.lua` |
| Login hook | `~/.config/hypr/lua/core/autostart.lua` -> `scripts/hyprpm-reload.sh` |
| Loaded plugin | `~/.local/lib/hypr/scrolloverview.so` |
| Local build | upstream `new-release` (`9a65855`, 2026-10-15) + PR #83 head (`7af2497`), so `hyprctl plugin list` reports version `7af2497494be` |
| hyprpm repo | `hyprland-scroll-overview` (by yayuuu), tracks `main`, state `failed = true` |
| hyprpm cache | `/var/cache/hyprpm/rx/hyprland-scroll-overview/` has `state.toml` only, no `.so` |
| dynamic-cursors | built, disabled |

`hyprpm list` currently prints:

```
→ Repository hyprland-scroll-overview (by yayuuu):
  │ Plugin scrolloverview
  └─ enabled: Plugin failed to build
```

The local `.so` exists because Hyprland 0.57 broke the plugin ABI and
`hyprpm update` cannot build upstream `main`. `new-release` has the render
fixes, PR #83 adds the event/bind fixes, and the combination compiles and
runs.

## Why the login error appears

Hyprland parses the Lua config **before** `hl.on("hyprland.start")` runs the
autostart commands. At that moment no plugin is loaded, so every
`plugin.scrolloverview.*` key is unknown and Hyprland shows
"Your config has errors".

The config therefore guards those keys:

```lua
if hl.plugin and hl.plugin.scrolloverview then
  hl.config({ plugin = { scrolloverview = { ... } } })
end
```

Do not remove that guard. The loader reloads the config after the plugin is
loaded so the options are applied for the session.

## Invariants

- Exactly one ScrollOverview instance must be loaded. Check `hyprctl plugin list`
  before loading another copy.
- The local `.so` is tied to the running Hyprland ABI. After any Hyprland,
  hyprutils, aquamarine, or hyprlang upgrade, either rebuild it or remove the
  local load so the login does not depend on a stale binary.
- `hyprpm update` writes to `/var/cache/hyprpm/rx` through `sudo`; it may prompt
  for a password. Do not run it non-interactively from an agent without a
  working sudo session.
- Never run `hyprpm purge-cache` as a first step. It deletes headers and all
  built plugins.
- `hyprctl dispatch scrolloverview:overview toggle` is invalid with the 0.57
  Lua config (Hyprland parses it as Lua). Use `hyprctl eval` or the keybind.

## Step 0: check whether the running headers match

A stale `headersRoot` produces false build failures. Compare commits:

```sh
hyprctl version | head -1
grep GIT_COMMIT_HASH /var/cache/hyprpm/rx/headersRoot/include/hyprland/src/version.h
grep GIT_COMMIT_HASH /usr/include/hyprland/src/version.h
```

All three must identify the running Hyprland. If `headersRoot` is stale:

```sh
hyprpm update -f          # sudo; refreshes headers and rebuilds plugins
```

If `hyprpm update` fails with `removePluginRepo` or permission errors:

```sh
sudo chown -R rx:rx /var/cache/hyprpm/rx
hyprpm update -f
```

Also compare `AQUAMARINE_VERSION` in the same two `version.h` files; the
major.minor must match (the plugin's version check strips the patch level).

## Step 1: decide the path

Test upstream `origin/new-release` against the current headers. This build is
throwaway and does not touch the running compositor.

```sh
rm -rf /tmp/so-check
git clone -b new-release --depth 1 \
  https://github.com/yayuuu/hyprland-scroll-overview /tmp/so-check
PKG_CONFIG_PATH=/var/cache/hyprpm/rx/headersRoot/share/pkgconfig \
  make -C /tmp/so-check all
```

- **Build succeeds** -> go to "Return to hyprpm". PR #83 is either merged or
  no longer needed.
- **Build fails** -> read the first error and go to "Keep/rebuild the local
  fallback". Do not migrate to hyprpm while this build fails.
- If the failure is only `callLuaFnBind` / `workspace.created`, check whether
  PR #83 is still open. If it is, the local fallback is the only working
  option.
- If the failure is in the render API (`m_renderPass`,
  `renderRoundedShadow`), `new-release` does not support the running Hyprland
  yet; stay on the fallback.

Check open PRs before building a custom mix:

```sh
curl -s 'https://api.github.com/repos/yayuuu/hyprland-scroll-overview/pulls?state=open&per_page=20'
```

## Step 2a: keep/rebuild the local fallback

Only when Step 1 failed. This is a stopgap built from an unmerged PR; keep the
rollback section at hand. Refresh headers first (Step 0), then:

```sh
rm -rf /tmp/so
git clone -b new-release --depth 1 \
  https://github.com/yayuuu/hyprland-scroll-overview /tmp/so

# Skip these two lines if PR #83 is already merged into new-release.
git -C /tmp/so fetch origin pull/83/head:pr83
git -C /tmp/so checkout pr83

PKG_CONFIG_PATH=/var/cache/hyprpm/rx/headersRoot/share/pkgconfig \
  make -C /tmp/so all

# Unload before replacing the file: the running plugin has it mapped.
hyprctl plugin unload "$HOME/.local/lib/hypr/scrolloverview.so" 2>/dev/null || true
install -Dm755 /tmp/so/scrolloverview.so \
  "$HOME/.local/lib/hypr/scrolloverview.so"
"$HOME/.config/hypr/scripts/hyprpm-reload.sh"
```

Verify with the checks in "Verification". The loader already contains a
marked block for this fallback:

```sh
# --- local scrolloverview fallback: delete this block after hyprpm can build
# --- origin/new-release against the running Hyprland ...
```

## Step 2b: return to hyprpm with origin/new-release

Only after Step 1 builds successfully.

```sh
# Stop the local copy first, so two instances cannot be loaded.
hyprctl plugin unload "$HOME/.local/lib/hypr/scrolloverview.so" 2>/dev/null || true

# Remove the failed repo entry. This normally handles sudo itself.
hyprpm remove hyprland-scroll-overview

# If remove fails on permissions:
#   sudo chown -R rx:rx /var/cache/hyprpm/rx
#   hyprpm remove hyprland-scroll-overview

hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git origin/new-release
hyprpm update
hyprpm enable scrolloverview
hyprpm reload
hyprctl reload
```

`hyprpm add <url> <rev>` is the documented way to install a branch. With a
revision set, commit locks are ignored so the branch can advance.

Then remove the fallback:

1. Edit `~/.config/hypr/scripts/hyprpm-reload.sh` and delete the block from
   the first `--- local scrolloverview fallback` line through the
   `--- end local scrolloverview fallback` line, inclusive.
2. Keep the rest of the script:

   ```sh
   hyprpm reload -n >/dev/null 2>&1
   hyprctl reload >/dev/null 2>&1
   ```

   The explicit `hyprctl reload` is required: the config guard skips
   `plugin.scrolloverview.*` until the plugin exists, so a reload after
   `hyprpm reload` applies the options.

3. Delete the local binary:

   ```sh
   rm -f "$HOME/.local/lib/hypr/scrolloverview.so"
   ```

Do not change `autostart.lua` back to a bare `hyprpm reload -n &` unless
`hyprpm reload` is confirmed to reload the config in that Hyprland version.
Keeping the script is harmless and preserves the explicit reload.

## Verification

All of these must pass:

```sh
hyprctl plugin list
# Expect exactly one "Plugin scrolloverview"; with hyprpm its Version should be
# the new-release commit, not 7af2497494be.

hyprctl -j configerrors
# Expect [""] -- any non-empty string is a real error.

hyprpm list
# After migration: "enabled", not "Plugin failed to build".
# With the fallback: the repo may still say failed; that is expected and the
# local .so is doing the work.

for k in gesture_distance scale workspace_gap layout wallpaper blur shadow.enabled; do
  printf '%s=' "$k"
  hyprctl getoption "plugin.scrolloverview:$k" | head -1
done
# Expect: 300, 0.5, 100, vertical, 0, false, false.
```

Functional check. This opens and closes the overview; run both commands:

```sh
hyprctl eval 'hl.plugin.scrolloverview.overview("toggle")'
sleep 1
hyprctl eval 'hl.plugin.scrolloverview.overview("toggle")'
```

If an overview is left open on a crash, close it with
`hl.plugin.scrolloverview.overview("close")`.

Check the loader syntax before finishing:

```sh
sh -n "$HOME/.config/hypr/scripts/hyprpm-reload.sh"
```

## Rollback

If the plugin crashes or fails to load after an upgrade:

```sh
hyprctl plugin unload "$HOME/.local/lib/hypr/scrolloverview.so" 2>/dev/null || true
mv "$HOME/.local/lib/hypr/scrolloverview.so" \
   "$HOME/.local/lib/hypr/scrolloverview.so.disabled"
```

The loader skips a missing file and the Lua guard keeps the config
error-free. The SUPER+O / SUPER+E binds become no-ops. To diagnose the loader:

```sh
hyprpm reload
hyprctl reload && hyprctl -j configerrors
```

Logs:

```sh
ls /run/user/1000/hypr/*/hyprland.log
journalctl --user -b | grep -Ei 'hyprpm|scrolloverview|plugin'
```

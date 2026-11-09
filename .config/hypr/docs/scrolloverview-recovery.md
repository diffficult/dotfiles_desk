# ScrollOverview recovery (hyprpm)

Status: **resolved 2026-11-09**. hyprpm builds and manages the plugin again;
the locally built `~/.local/lib/hypr/scrolloverview.so` fallback and its loader
block are gone. This file is now the procedure for the next ABI break, not a
to-do list.

## Current state

| Item | Value |
|---|---|
| Hyprland | 0.57.1, commit `acc1aa0bfd4bd575dcb0f76c35ccf12b660a1ab9` |
| Config entrypoint | `~/.config/hypr/hyprland.lua` |
| Plugin config/binds | `~/.config/hypr/lua/integrations/scrolloverview.lua` |
| Login hook | `~/.config/hypr/lua/core/autostart.lua` -> `scripts/hyprpm-reload.sh` (`hyprpm reload -n`, then `hyprctl reload`) |
| Managed build | `/var/cache/hyprpm/rx/hyprland-scroll-overview/scrolloverview.so` |
| hyprpm repo | `hyprland-scroll-overview` (by yayuuu), tracks `main` with no revision, `enabled = true` |
| Built revision | `3eb62e3e0093` (`hyprctl plugin list` reports it) |
| Build headers | `/var/cache/hyprpm/rx/headersRoot`, refreshed 2026-11-09 to 0.57.1 / aquamarine 0.16.0 |
| dynamic-cursors | built, disabled |

`hyprctl plugin list` must show exactly one entry, with the revision hyprpm
last built. `hyprpm list` must say `enabled: true`, not `Plugin failed to
build`.

## Why the login config error appears

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

Do not remove that guard. `scripts/hyprpm-reload.sh` reloads the config after
`hyprpm reload` so the options are applied for the session.

## Invariants

- Exactly one ScrollOverview instance. `hyprctl plugin list` before loading
  anything by hand.
- hyprpm builds against the cached headers. They are only correct while
  `headersRoot` matches the running compositor (see Step 0).
- `hyprpm update` writes to `/var/cache/hyprpm/rx` through `sudo`.
- Never run `hyprpm purge-cache` as a first step. It deletes headers and all
  built plugins.
- `hyprctl dispatch scrolloverview:overview toggle` is invalid with the 0.57
  Lua config (Hyprland parses it as Lua). Use `hyprctl eval` or the keybind.

## When the plugin stops working

Symptom is usually silent: SUPER+O / SUPER+E do nothing, `hyprctl plugin list`
prints `no plugins loaded`, and `hyprctl configerrors` is still empty because of
the Lua guard.

### Step 0: check whether the cached headers match

```sh
hyprctl version | head -1
grep GIT_COMMIT_HASH /var/cache/hyprpm/rx/headersRoot/include/hyprland/src/version.h
grep GIT_COMMIT_HASH /usr/include/hyprland/src/version.h
grep AQUAMARINE_VERSION /var/cache/hyprpm/rx/headersRoot/include/hyprland/src/version.h \
                         /usr/include/hyprland/src/version.h
```

All commits must be the running one and the aquamarine major.minor must match.
Mismatch (or a plugin that loads and then reports `Version mismatch` via an
explicit `hyprctl plugin load`) means the cache is stale:

```sh
sudo chown -R rx:rx /var/cache/hyprpm/rx   # only if permission errors appear
hyprpm update -f                            # refreshes headers, rebuilds plugins
```

Plain `hyprpm update` skips the header refresh when the Hyprland commit is
unchanged, which is how packaging-only rebuilds (dependency bumps) leave a
stale cache behind. Use `-f` after any hyprland/aquamarine/hyprutils/hyprlang
upgrade.

### Step 1: rebuild through hyprpm

```sh
hyprpm update -f
hyprpm enable scrolloverview
hyprpm reload
hyprctl reload
hyprctl -j configerrors     # expect [""]
```

### Step 2: only if upstream `main` cannot build

`hyprpm update -f` leaves `failed = true` for the repo and no `.so`. Check
whether `origin/new-release` builds (on 2026-10-28 it was the only branch with
the 0.57 render fixes; PR #83 followed on 2026-11-01 and both are in `main`
now):

```sh
rm -rf /tmp/so-check
git clone -b new-release --depth 1 \
  https://github.com/yayuuu/hyprland-scroll-overview /tmp/so-check
make -C /tmp/so-check all        # uses system hyprland.pc, not the cache
```

If it builds, point hyprpm at that branch and drop the branch again once
`main` catches up:

```sh
hyprpm remove hyprland-scroll-overview
hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git origin/new-release
hyprpm update
hyprpm enable scrolloverview
hyprpm reload
hyprctl reload
```

With a revision set, commit locks are ignored and hyprpm follows the branch on
every `update`. If both branches fail, read the first compiler error: a render
API error (`m_renderPass`, `renderRoundedShadow`) means the plugin has no
support for the running Hyprland yet; report upstream and fall back to the
previous Hyprland until it does.

## Verification

All of these must pass:

```sh
hyprctl plugin list
# Expect exactly one "Plugin scrolloverview" with the built revision.

hyprctl -j configerrors
# Expect [""] -- any non-empty string is a real error.

hyprpm list
# Expect: enabled: true

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

Prove the login path: unload, then run the hook the way autostart does.

```sh
hyprctl plugin unload /var/cache/hyprpm/rx/hyprland-scroll-overview/scrolloverview.so
sh -n "$HOME/.config/hypr/scripts/hyprpm-reload.sh"
sh "$HOME/.config/hypr/scripts/hyprpm-reload.sh"
hyprctl plugin list          # plugin back, same revision
hyprctl -j configerrors      # [""]
```

## Rollback

Disable the plugin without touching the Lua config (the guard keeps
`plugin.scrolloverview.*` out of the parse when it is not loaded):

```sh
hyprpm disable scrolloverview
hyprpm reload
hyprctl reload && hyprctl -j configerrors
```

SUPER+O / SUPER+E become no-ops. Re-enable with `hyprpm enable scrolloverview`.

Logs:

```sh
ls /run/user/1000/hypr/*/hyprland.log
journalctl --user -b | grep -Ei 'hyprpm|scrolloverview|plugin'
```

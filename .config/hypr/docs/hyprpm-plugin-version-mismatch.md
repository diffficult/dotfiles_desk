# hyprpm plugin "unknown config key" / Version mismatch runbook

Seen 2026-09-13: after `hyprland 0.56.2-2 → -3`, every
`plugin.scrolloverview.*` key errored as `unknown config key`
(`hyprctl configerrors` showed 10), although the Lua config was valid.

## Root cause

The plugin never loaded, so Hyprland knew none of its config keys.
`hyprctl plugin load <scrolloverview.so>` failed with:

```
plugin crashed/threw in main: [he] Version mismatch
```

The string `Version mismatch (headers ver is not equal to running
hyprland ver)` lives in the plugin: its `PLUGIN_INIT` compares the
build-time header hash (`__hyprland_api_get_client_hash()`) against the
running compositor. The plugin was built against hyprpm's cached headers
`/var/cache/hyprpm/rx/headersRoot` (aquamarine 0.14.0, from Aug 9) while
the running Hyprland 0.56.2-3 was built against aquamarine 0.15.0
(patch version is stripped, so only major.minor matters).

Why the cache went stale: plain `hyprpm update` prints
`Headers up to date` based on the Hyprland *commit hash only*.
`0.56.2-1/-2/-3` are packaging-only rebuilds of the same commit
(`efb5099`), so a dep bump (aquamarine 0.14 → 0.15 on Sep 5) never
triggered a header refresh. Only `hyprpm update -f` re-clones Hyprland
("checked out to running ver" → "installed headers").

Contributing factor: `/var/cache/hyprpm/rx/*` was partly root-owned, so
user-run `hyprpm update` failed with
`[ERR] removePluginRepo: failed to remove dir` and left corrupt state.
Fixed with `sudo chown -R rx:rx /var/cache/hyprpm/rx`; keep it that way.

## Diagnose

```sh
hyprctl plugin list            # "no plugins loaded" = nothing actually loaded
hyprctl configerrors           # unknown config key 'plugin.<name>.*'
hyprctl plugin load /var/cache/hyprpm/rx/<repo>/<plugin>.so  # real error surfaces here
grep AQUAMARINE_VERSION /var/cache/hyprpm/rx/headersRoot/include/hyprland/src/version.h
grep AQUAMARINE_VERSION /usr/include/hyprland/src/version.h  # ground truth
hyprctl version                # "built against" vs "system has" lines
```

If the two `version.h` files disagree on a major.minor (or the load
says `Version mismatch`), the header cache is stale.

## Fix

```sh
hyprpm update -f               # refreshes headersRoot, rebuilds all plugins
hyprctl plugin load /run/user/1000/hyprpm/rx/<plugin>.so   # sanity-load the fresh build
hyprctl plugin list            # must show the plugin
sudo install -m0755 /run/user/1000/hyprpm/rx/<plugin>.so /var/cache/hyprpm/rx/<repo>/
hyprpm reload && hyprctl reload
hyprctl configerrors           # must be empty
```

(`hyprpm update -f` as your user cannot write the root-owned cache
dirs; the `install` step covers that. With the `chown` fix above,
subsequent plain `hyprpm update` runs no longer hit permission errors.)

## Prove it survives a reboot (same path autostart takes)

```sh
hyprctl plugin unload /run/user/1000/hyprpm/rx/<plugin>.so  # unload needs the loaded path, not the name
hyprctl plugin list            # expect: no plugins loaded
hyprpm reload                  # what `exec-once = hyprpm reload -n` does at login
hyprctl plugin list            # expect: plugin back with a NEW handle
hyprctl reload && hyprctl configerrors  # expect: empty
```

## After every hyprland/aquamarine/hyprutils/hyprlang update

1. `hyprctl plugin list` — if empty, or `hyprctl configerrors` shows
   `unknown config key 'plugin.*'`, run the Fix section above
   (`-f` matters: plain `update` skips header refresh on same-commit rebuilds).
2. If you see `[ERR] removePluginRepo` / permission errors, re-check
   ownership: everything under `/var/cache/hyprpm/rx` must be `rx:rx`.

## 2026-10-28 — Hyprland 0.57.0 API break (scrolloverview)

`hyprpm update` cannot build scroll-overview `main` against 0.57.0
(`0aa6745`); it leaves `failed = true` and no `.so`, so all
`plugin.scrolloverview.*` keys are unknown. `new-release` fixes the render
API but still needs PR #83 for `workspace.createdLate` / `CBind::invoke()`.

The full diagnosis, local build procedure, and the steps to migrate back to
`hyprpm add <url> origin/new-release` are in
[`scrolloverview-recovery.md`](scrolloverview-recovery.md). That file is
written to be executed by an agent; follow it top to bottom.

Short version of the current workaround: local build at
`~/.local/lib/hypr/scrolloverview.so`, loaded by
`scripts/hyprpm-reload.sh`, with the plugin config guarded in
`lua/integrations/scrolloverview.lua`.

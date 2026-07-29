# Hyprland Lua Migration

This config now uses a Lua entrypoint. The old Hyprland hyprlang files were moved out of the live config tree to `~/.config/hypr_conf_bkp/`.

The current live Hyprland process may still be running under the legacy config manager if it was started before `hyprland.lua` existed. In that case, `hyprctl reload` keeps using `hyprland.conf`; it does not switch config managers mid-session.

## Quick Path

1. Hyprland loads `~/.config/hypr/hyprland.lua` when present.
2. Core Hyprland config lives in Lua under `hyprland.lua` and `lua/**`.
3. The old `.conf` schema is backed up in `~/.config/hypr_conf_bkp/`.

## Current Shape

| Area | Lua location | Notes |
|------|--------------|-------|
| Entry point | `hyprland.lua` | Requires modules in load order. |
| Monitors/workspaces | `lua/core/monitors.lua` | Native `hl.monitor` and `hl.workspace_rule`. |
| Env | `lua/core/env.lua` | Runtime `hl.env`; long-lived uwsm env should move outside Hyprland config later. |
| General config | `lua/core/general.lua` | Native `hl.config`. |
| Autostart | `lua/core/autostart.lua` | Uses `hl.on("hyprland.start", ...)` plus `hl.dsp.exec_cmd`. |
| Rules | `lua/core/rules.lua`, `lua/rules/**` | Native `hl.window_rule` modules generated from the previous rule files. |
| Base binds | `lua/core/keybindings.lua`, `lua/lib/binds.lua` | Native Lua bind/submap declarations generated from `keybindings.conf`. |
| Warmind Launcher | `lua/integrations/warmind_launcher.lua` | Placeholder for the new launcher-owned Lua module. |

## Rollback

### Current Session Bridge

If the running compositor was started in legacy mode, keep `~/.config/hypr/hyprland.conf` as a temporary bridge. It sources files from `~/.config/hypr_conf_bkp/` so `hyprctl reload` keeps the current session usable.

After restarting Hyprland into Lua mode, remove the bridge if it still exists:

```bash
rm ~/.config/hypr/hyprland.conf
hyprctl reload
```

Verify the compositor is no longer using the legacy bridge by checking that the expected Lua binds/rules are active.

### Full Legacy Restore

To restore the old hyprlang config from backup:

```bash
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.disabled
cp -a ~/.config/hypr_conf_bkp/hyprland.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/monitors.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/env.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/general.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/rules.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/autostart.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/plugins.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/keybindings.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/warmind-launcher.conf ~/.config/hypr/
cp -a ~/.config/hypr_conf_bkp/apps ~/.config/hypr/
hyprctl reload
```

To re-enable Lua:

```bash
rm -f ~/.config/hypr/hyprland.conf ~/.config/hypr/monitors.conf ~/.config/hypr/env.conf ~/.config/hypr/general.conf ~/.config/hypr/rules.conf ~/.config/hypr/autostart.conf ~/.config/hypr/plugins.conf ~/.config/hypr/keybindings.conf ~/.config/hypr/warmind-launcher.conf
rm -rf ~/.config/hypr/apps
mv ~/.config/hypr/hyprland.lua.disabled ~/.config/hypr/hyprland.lua
hyprctl reload
```

## Migration Rules

- Use native Lua helpers when the syntax is stable and clear.
- Keep generated integrations out of the live tree once their hyprlang output is no longer active.
- Preserve load order. Warmind Launcher should load after base keybindings when its Lua module is integrated, because it intentionally overrides base binds.
- Use escaped Lua strings or Lua long strings for regex-heavy rules.
- Keep shell-heavy commands as complete strings. Do not split commands by spaces or commas.
- For keybind dispatchers, use Lua `hl.bind`/`hl.define_submap` first. Route unclear dispatcher helpers through `hyprctl dispatch` to preserve behavior.
- `hl.monitor` uses Monitor v2-style keys: `output`, `mode`, `position`, and `scale`.
- Simple colors use numeric `0xRRGGBBAA` values in Lua.
- Gradients use `{ colors = { 0xRRGGBBAA, 0xRRGGBBAA }, angle = NUMBER }`.
- Hyprlang keys containing `-` may become underscore keys in Lua tables, e.g. `tap-to-click` -> `tap_to_click`.

## Reusable Checklist

- [ ] Inventory sourced `.conf` files and preserve their load order.
- [ ] Convert monitors, workspaces, env, and general config first.
- [ ] Convert autostart with `hl.on("hyprland.start", ...)`.
- [x] Convert rules to `hl.window_rule` modules.
- [x] Convert base binds to `hl.bind` and `hl.define_submap`.
- [x] Move deprecated hyprlang files to `~/.config/hypr_conf_bkp/` after Lua is proven stable.
- [ ] Load the new Warmind Launcher Lua module after base keybindings.

## Validation

After the pure Lua cleanup:

```bash
lua <mock validation script>
hyprctl reload
hyprctl configerrors
hyprctl binds -j | jq 'length'
```

Expected checks:

- `hyprctl reload` returns `ok`.
- `hyprctl configerrors` is empty.
- Bind count remains stable.
- Warmind Launcher overrides should be rechecked after integrating its new Lua module.
- Submaps like `resize` and `gaps` expose their `Escape -> reset` binds.
- If bind count drops to Hyprland defaults, the current compositor is still using the legacy config manager and needs the temporary bridge or a full restart into Lua mode.

## Warmind Launcher Notes

Warmind Launcher's old hyprlang output was moved to `~/.config/hypr_conf_bkp/warmind-launcher.conf`. The live Hyprland config no longer reads it.

When migrating Warmind Launcher itself, emit Lua directly instead of hyprlang:

- `unbind = MODS, KEY` -> `hl.unbind("MODS + KEY")`
- `bind = MODS, KEY, exec, CMD` -> `hl.bind("MODS + KEY", hl.dsp.exec_cmd("CMD"))`
- `windowrule { ... }` -> `hl.window_rule({ match = { ... }, ... })`

Keep the new Lua integration loaded after base keybindings so launcher overrides remain intentional.

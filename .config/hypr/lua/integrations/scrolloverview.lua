-- The plugin is loaded at login by scripts/hyprpm-reload.sh. It is not present
-- during the first config parse, so only register its keys once it is loaded;
-- otherwise Hyprland reports every plugin.* key as unknown.
if hl.plugin and hl.plugin.scrolloverview then
  hl.config({
    plugin = {
      scrolloverview = {
        gesture_distance = 300,
        scale = 0.5,
        workspace_gap = 100,
        layout = "vertical",
        wallpaper = 0,
        blur = false,
        shadow = {
          enabled = false,
          range = 50,
          render_power = 3,
          color = 0xee1a1a1a,
        },
      },
    },
  })
end

local function toggle_overview()
  if hl.plugin and hl.plugin.scrolloverview then
    hl.plugin.scrolloverview.overview("toggle")
  end
end

hl.bind("SUPER + o", toggle_overview)
hl.bind("SUPER + e", toggle_overview)

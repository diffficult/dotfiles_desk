-- Core window rules.

hl.window_rule({
  match = {
    class = ".*",
  },
  suppress_event = "maximize",
})

hl.window_rule({
  match = {
    class = "^$",
    title = "^$",
    xwayland = 1,
    float = 1,
    fullscreen = 0,
    pin = 0,
  },
  no_focus = true,
})

hl.window_rule({
  name = "core-tag-no-border",
  match = {
    tag = "+no-border",
  },
  border_size = 0,
})

hl.window_rule({
  name = "core-tag-media-opaque",
  match = {
    tag = "+media",
  },
  opaque = true,
})

hl.window_rule({
  name = "core-tag-password-manager-security",
  match = {
    tag = "+password-manager",
  },
  no_screen_share = true,
})

hl.window_rule({
  name = "core-file-dialog-float",
  match = {
    title = "^(Open File|Save File|Save As|Open Document)$",
  },
  float = true,
  center = true,
  border_size = 0,
})

hl.window_rule({
  name = "core-about-dialog-float",
  match = {
    title = "^(About ).*$",
  },
  float = true,
})

hl.window_rule({
  name = "core-file-progress-float",
  match = {
    class = "^(file_progress)$",
  },
  float = true,
})

hl.window_rule({
  name = "core-generic-dialog-float",
  match = {
    class = "^(.*-picker|.*-dialog|.*-preferences)$",
  },
  float = true,
})

hl.window_rule({
  name = "core-zenity-no-border",
  match = {
    class = "^(zenity)$",
  },
  border_size = 0,
})

hl.window_rule({
  name = "core-window-type-float",
  match = {
    title = "^(pop-up|task_dialog|bubble|dialog|menu|Preferences)$",
  },
  float = true,
})

hl.window_rule({
  name = "core-footclient-float",
  match = {
    class = "^(footclient-float.*)$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "core-footclient-cpu",
  match = {
    title = "^(CPU.*)$",
  },
  size = "900 720",
})

hl.window_rule({
  name = "core-footclient-weather",
  match = {
    title = "^(Weather.*)$",
  },
  size = "924 1196",
})

hl.window_rule({
  name = "core-footclient-yay",
  match = {
    title = "^(yay.*)$",
  },
  size = "800 760",
})

hl.window_rule({
  name = "core-warmind-install-tui",
  match = {
    class = "^(warmind\\.install\\.tui)$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "core-warmind-install-webapp",
  match = {
    class = "^(warmind\\.install\\.webapp)$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "core-st-float-variants",
  match = {
    class = "^(St|drawn-st|floating-kitty|floating_update)$",
  },
  float = true,
})

hl.window_rule({
  name = "core-st-title-float",
  match = {
    class = "^(st)$",
    title = "^(st)$",
  },
  float = true,
})

hl.window_rule({
  name = "core-waybar-manager-float",
  match = {
    class = "^(waybar-manager)$",
  },
  float = true,
  size = "800 600",
  center = true,
})

hl.window_rule({
  name = "core-waybar-widget-float",
  match = {
    class = "^(floating-waybar-(cpu|weather|pacman|calendar))$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "core-terminal-workspace-2",
  match = {
    class = "^(Xfce4-terminal|Alacritty)$",
  },
  workspace = 2,
})

hl.window_rule({
  name = "core-kitty-workspace-2-float",
  match = {
    class = "^(kitty)$",
  },
  float = true,
  workspace = 2,
  size = "1386 1373",
  move = "1160 53",
})

hl.window_rule({
  name = "core-wezterm-workspace-8",
  match = {
    class = "^(wezterm|Wezterm)$",
  },
  workspace = 8,
})

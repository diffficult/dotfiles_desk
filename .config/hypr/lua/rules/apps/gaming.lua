-- Gaming window rules.

hl.window_rule({
  name = "gaming-steam-tag",
  match = {
    class = "^(steam|Steam|steam_app_.*)$",
  },
  tag = "+gaming",
})

hl.window_rule({
  name = "gaming-retroarch-tag",
  match = {
    class = "com.libretro.RetroArch",
  },
  tag = "+gaming",
})

hl.window_rule({
  name = "gaming-winboat-float",
  match = {
    class = "^winboat$",
  },
  float = true,
  center = true,
})

hl.window_rule({
  name = "gaming-steam-ui-float",
  match = {
    class = "^(steam|Steam)$",
  },
  float = true,
  center = true,
  workspace = 8,
})

hl.window_rule({
  name = "gaming-steam-client-main",
  match = {
    class = "^(steam|Steam)$",
    title = "^(steam|Steam)$",
  },
  opacity = "1 override 1 override",
  size = "2350 1280",
})

hl.window_rule({
  name = "gaming-steam-friends-list",
  match = {
    class = "^(steam|Steam)$",
    title = "^(Friends List)$",
  },
  size = "460 800",
})

hl.window_rule({
  name = "gaming-steam-idle-inhibit",
  match = {
    class = "^(steam|Steam)$",
  },
  idle_inhibit = "fullscreen",
  workspace = 8,
})

hl.window_rule({
  name = "gaming-steam-game-immediate",
  match = {
    class = "^(steam_app_.*|cs2)$",
    initial_title = "negative:^QTrayIconMessageWindow$",
  },
  immediate = true,
  workspace = 8,
})

hl.window_rule({
  name = "gaming-steam-game-fullscreen",
  match = {
    class = "^(steam_app_.*)$",
    initial_title = "negative:^(QTrayIconMessageWindow|Heroes of the Storm.*)$",
  },
  fullscreen = true,
  workspace = 8,
})

hl.window_rule({
  name = "gaming-retroarch-fullscreen",
  match = {
    class = "com.libretro.RetroArch",
  },
  fullscreen = true,
  opaque = true,
  idle_inhibit = "fullscreen",
})

-- Lutris launcher: keep its main window on the gaming workspace.
hl.window_rule({
  name = "gaming-lutris-float-center",
  match = {
    class = "^net\\.lutris\\.Lutris$",
  },
  float = true,
  center = true,
  workspace = 8,
})

-- Battle.net's launcher window shares its class with Proton games.
hl.window_rule({
  name = "gaming-battlenet-float-center",
  match = {
    class = "^steam_app_default$",
    initial_title = "^Battle\\.net$",
  },
  float = true,
  center = true,
  fullscreen = false,
  workspace = 8,
})

-- Battle.net uses a screen-sized X11 helper for toast notifications.
hl.window_rule({
  name = "gaming-battlenet-notification",
  match = {
    class = "^steam_app_default$",
    initial_title = "^QTrayIconMessageWindow$",
  },
  float = true,
  fullscreen = false,
  pin = true,
  no_focus = true,
  no_initial_focus = true,
  no_dim = true,
  border_size = 0,
})

-- Keep Heroes of the Storm floating and reject fullscreen requests.
hl.window_rule({
  name = "gaming-heroes-of-the-storm-floating",
  match = {
    class = "^steam_app_default$",
    initial_title = "^Heroes of the Storm.*$",
  },
  immediate = true,
  float = true,
  center = true,
  size = "1920 1080",
  fullscreen = false,
  fullscreen_state = "0 0",
  suppress_event = "fullscreen",
  allows_input = true,
  workspace = 8,
})

hl.window_rule({
  name = "gaming-starcraft-fullscreen",
  match = {
    class = "^steam_app_default$",
    initial_title = "^Star[Cc]raft( II)?$",
  },
  immediate = true,
  fullscreen = true,
  workspace = 8,
})

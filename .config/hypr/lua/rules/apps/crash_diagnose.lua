-- Crash diagnose (agy/antigravity) window rules.

hl.window_rule({
  name = "crash-diagnose-float-center",
  match = {
    class = "^agent-crash-watch$",
    title = "^crash-diagnose:.*",
  },
  float = true,
  center = true,
  size = "1257 690",
})

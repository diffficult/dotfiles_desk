-- Warmind webapp window rules.

hl.window_rule({
  name = "chrome-webapp-grok",
  match = {
    class = "^(chrome|brave)-grok\\.com__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "chrome-webapp-chatgpt",
  match = {
    class = "^(chrome-chatgpt\\.com__-Default|brave-www\\.chatgpt\\.com__-Default)$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "chrome-webapp-stitch",
  match = {
    class = "^brave-stitch\\.withgoogle\\.com__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "chrome-webapp-flow",
  match = {
    class = "^brave-labs\\.google__fx_tools_flow-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "chrome-webapp-gemini",
  match = {
    class = "^(chrome|brave)-gemini\\.google\\.com__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-gmail",
  match = {
    class = "^brave\\-www\\.gmail\\.com__\\-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-claude",
  match = {
    class = "^brave-claude\\.ai-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-proton-mail",
  match = {
    class = "^brave-mail\\.proton\\.me-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-santander-empresas",
  match = {
    class = "^brave-empresas\\.santander\\.com\\.ar__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-word-web",
  match = {
    class = "^brave-origin-beta-word\\.cloud\\.microsoft__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-excel-web",
  match = {
    class = "^brave-origin-beta-excel\\.cloud\\.microsoft__-Default$",
  },
  float = true,
  center = true,
  size = "1280 1340",
  tag = "+chrome-webapp",
})

hl.window_rule({
  name = "warmind-webapp-youtube",
  match = {
    class = "^brave-origin-beta-www\\.youtube\\.com__-Default$",
  },
  float = true,
  center = true,
  size = "912 670",
  tag = "+chrome-webapp",
})

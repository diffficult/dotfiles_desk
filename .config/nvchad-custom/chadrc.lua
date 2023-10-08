---@type ChadrcConfig
local M = {}

-- Path to overriding theme and highlights files
M.ui = {
 theme_toggle = { "tokyonight", "catppuccin" },
 theme = 'tokyonight',
-- hl_override = highlights.override,
-- hl_add = highlights.add,
--- custom status line config
 statusline = {
  theme = "vscode_colored", -- default/vscode/vscode_colored/minimal
   -- default/round/block/arrow separators work only for default statusline theme
   -- round and block will work for minimal theme only
   separator_style = "round",
   overriden_modules = nil,
 },
  extended_integrations = {
    "dap",
    "hop",
    "rainbowdelimiters",
    "codeactionmenu",
    "todo",
    "trouble",
    "notify",
  },
-- nvdash (dashboard)
 nvdash = {
   load_on_startup = true,

   header = {
 	[[                                                     ]],
 	[[  ███▄    █ ▓█████  ▒█████   ██▒   █▓ ██▓ ███▄ ▄███▓ ]],
 	[[  ██ ▀█   █ ▓█   ▀ ▒██▒  ██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒ ]],
 	[[ ▓██  ▀█ ██▒▒███   ▒██░  ██▒ ▓██  █▒░▒██▒▓██    ▓██░ ]],
 	[[ ▓██▒  ▐▌██▒▒▓█  ▄ ▒██   ██░  ▒██ █░░░██░▒██    ▒██  ]],
 	[[ ▒██░   ▓██░░▒████▒░ ████▓▒░   ▒▀█░  ░██░▒██▒   ░██▒ ]],
 	[[ ░ ▒░   ▒ ▒ ░░ ▒░ ░░ ▒░▒░▒░    ░ ▐░  ░▓  ░ ▒░   ░  ░ ]],
 	[[ ░ ░░   ░ ▒░ ░ ░  ░  ░ ▒ ▒░    ░ ░░   ▒ ░░  ░      ░ ]],
  	[[    ░   ░ ░    ░   ░ ░ ░ ▒       ░░   ▒ ░░      ░    ]],
 	[[          ░    ░  ░    ░ ░        ░   ░         ░    ]],
 	[[                                 ░                   ]],
  	[[                                                     ]],
   },

   buttons = {
     { "  Find File", "Spc f f", "Telescope find_files" },
     { "󰈚  Recent Files", "Spc f o", "Telescope oldfiles" },
     { "󰈭  Find Word", "Spc f w", "Telescope live_grep" },
     { "  Bookmarks", "Spc m a", "Telescope marks" },
     { "  Themes", "Spc t h", "Telescope themes" },
     { "  Mappings", "Spc c h", "NvCheatsheet" },
   },
 },
}

M.plugins = 'custom.plugins'
-- check core.mappings for table structure
M.mappings = require "custom.mappings"

return M

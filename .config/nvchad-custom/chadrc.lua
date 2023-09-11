---@type ChadrcConfig 
 local M = {}
 M.ui = {
  theme_toggle = { "tokyonight", "catppuccin" },
  theme = 'tokyonight',
--- custom status line config 
  statusline = {
    theme = "minimal", -- default/vscode/vscode_colored/minimal
    -- default/round/block/arrow separators work only for default statusline theme
    -- round and block will work for minimal theme only
    separator_style = "round",
    overriden_modules = nil,
  },
 }
 return M

-- The active dotfiles theme for Neovim.
--
-- `dot theme set <id>` writes ~/.local/state/dotfiles/theme/nvim.lua
-- (returns { plugin, scheme, background }) and then calls reload() in every
-- running Neovim through its server socket, so open windows switch too.
local M = {}

M.fallback = { plugin = "folke/tokyonight.nvim", scheme = "tokyonight-night", background = "dark" }

local function state_file()
  return (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/dotfiles/theme/nvim.lua"
end

--- The active theme, or the fallback when none was applied yet.
function M.read()
  local ok, theme = pcall(dofile, state_file())
  if ok and type(theme) == "table" and type(theme.scheme) == "string" and theme.scheme ~= "" then
    return theme
  end
  return M.fallback
end

--- Switch this Neovim to the active theme. lazy.nvim loads the theme's
--- plugin on demand when the colorscheme is set.
function M.reload()
  local theme = M.read()
  vim.o.background = theme.background == "light" and "light" or "dark"
  local ok, err = pcall(vim.cmd.colorscheme, theme.scheme)
  if not ok then
    vim.notify("dotfiles: colorscheme " .. theme.scheme .. " failed: " .. tostring(err), vim.log.levels.WARN)
    return ""
  end
  return theme.scheme
end

return M

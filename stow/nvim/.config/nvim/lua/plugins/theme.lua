-- Colorscheme follows the active dotfiles theme (see lua/dotfiles/theme.lua).
-- Every theme's plugin is declared here (lazy, so only the active one
-- loads); new themes in themes/ are picked up without editing this file.
local dotfiles_theme = require("dotfiles.theme")
local theme = dotfiles_theme.read()

local dotfiles = vim.env.DOTFILES_DIR or (vim.env.HOME .. "/dotfiles")
local specs, seen = {}, {}
local function add(plugin)
  if plugin and plugin ~= "" and not seen[plugin] then
    seen[plugin] = true
    table.insert(specs, { plugin, lazy = true })
  end
end

for _, file in ipairs(vim.fn.glob(dotfiles .. "/themes/*/theme.json", false, true)) do
  local ok, meta = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  if ok and type(meta) == "table" then
    add(meta.nvim_plugin)
  end
end
add(dotfiles_theme.fallback.plugin)

vim.o.background = theme.background == "light" and "light" or "dark"
table.insert(specs, { "LazyVim/LazyVim", opts = { colorscheme = theme.scheme } })

return specs

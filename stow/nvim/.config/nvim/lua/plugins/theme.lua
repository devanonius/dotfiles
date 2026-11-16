-- Colorscheme follows the active dotfiles theme.
--
-- `dot theme set <id>` writes ~/.local/state/dotfiles/theme/nvim.lua,
-- which returns { plugin, scheme, background } from themes/<id>/theme.json.
-- Every theme's plugin is declared here (lazy, so only the active one
-- loads); new themes in themes/ are picked up without editing this file.
-- Open Neovim windows switch on the next start (live reload: phase 5).

local fallback = { plugin = "folke/tokyonight.nvim", scheme = "tokyonight-night", background = "dark" }

local state = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/dotfiles/theme/nvim.lua"
local ok, theme = pcall(dofile, state)
if not ok or type(theme) ~= "table" or not theme.scheme then
  theme = fallback
end

local dotfiles = vim.env.DOTFILES_DIR or (vim.env.HOME .. "/dotfiles")
local specs, seen = {}, {}
local function add(plugin)
  if plugin and plugin ~= "" and not seen[plugin] then
    seen[plugin] = true
    table.insert(specs, { plugin, lazy = true })
  end
end

for _, file in ipairs(vim.fn.glob(dotfiles .. "/themes/*/theme.json", false, true)) do
  local okj, meta = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
  if okj and type(meta) == "table" then
    add(meta.nvim_plugin)
  end
end
add(fallback.plugin)

vim.o.background = theme.background == "light" and "light" or "dark"
table.insert(specs, { "LazyVim/LazyVim", opts = { colorscheme = theme.scheme } })

return specs

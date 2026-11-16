-- Theme colors. Defaults are Tokyo Night; the theme engine (pywal16,
-- phase 3) writes ~/.cache/wal/colors-hyprland.lua, which returns a table
-- with the same keys and replaces these when present.
local colors = {
  active   = "rgb(7aa2f7)",  -- accent
  active2  = "rgb(bb9af7)",  -- accent_alt, for the gradient
  inactive = "rgb(3b4261)",  -- border
  shadow   = "rgba(1a1b26ee)",
}

local path = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/wal/colors-hyprland.lua"
local ok, theme = pcall(dofile, path)
if ok and type(theme) == "table" then
  for key, value in pairs(theme) do colors[key] = value end
end

-- Lua configs take a gradient as a table, not hyprlang's
-- "color color 45deg" string (wiki: Configuring/Basics/Variables, "gradient").
hl.config({
  general = {
    col = {
      active_border   = { colors = { colors.active, colors.active2 }, angle = 45 },
      inactive_border = colors.inactive,
    },
  },
  decoration = {
    shadow = { color = colors.shadow },
  },
})

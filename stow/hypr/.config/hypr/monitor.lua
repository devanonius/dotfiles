-- Fallback for every monitor: preferred mode, placed automatically.
-- Real layouts for a given machine go in local/monitors.lua, e.g.
--   hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
-- (list outputs with: hyprctl monitors)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

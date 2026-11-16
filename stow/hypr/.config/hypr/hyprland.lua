-- Hyprland entry point (Hyprland 0.55+, Lua only).
-- Each require() runs in its own scope, so an error in one file does not
-- stop the others. Order matters: later files can override earlier ones.
--
-- Machine-specific settings go in ~/.config/hypr/local/*.lua (untracked,
-- not part of the repo). They load last and may be missing.

require("env")
require("monitor")
require("input")
require("layout")
require("theme")
require("animations")
require("rules")
require("binds")
require("autostart")

local dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/local/"
for _, name in ipairs({ "env", "monitors", "input", "binds", "overrides" }) do
  local file = io.open(dir .. name .. ".lua", "r")
  if file then
    file:close()
    require("local/" .. name)
  end
end

-- Preferred applications. Other files read these with require("defaults").
-- Change them here (or override in local/overrides.lua) instead of editing binds.
return {
  terminal    = "ghostty",
  launcher    = "walker",
  fileManager = "nautilus",
  browser     = "xdg-open https://",  -- replaced by the browser chosen in phase 7
  editor      = "ghostty -e nvim",
  locker      = "hyprlock",
  -- Every app is started through uwsm so it runs in its own systemd scope.
  launch      = function(cmd) return "uwsm app -- " .. cmd end,
}

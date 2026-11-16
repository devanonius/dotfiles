-- Environment variables for the session.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Our scripts (dot, dot-power-menu, ...) live in ~/.local/bin. A login
-- screen starts the session without reading ~/.zprofile, so put the folder
-- on PATH here too, or binds like SUPER+SHIFT+T can't find `dot`.
-- (uwsm sessions also get it from ~/.config/uwsm/env.)
do
  local bin = os.getenv("HOME") .. "/.local/bin"
  local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
  if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then
    hl.env("PATH", bin .. ":" .. path)
  end
end

-- Programs started with the session. hypridle, hyprpolkitagent and
-- elephant (Walker's backend) run as systemd user services instead,
-- enabled by the installer (stage 70-services).
--
-- Output goes to ~/.local/state/dotfiles/autostart/<name>.log, so a program
-- that exits at startup leaves a reason behind.
local apps = require("defaults")

local logdir = os.getenv("HOME") .. "/.local/state/dotfiles/autostart"
os.execute("mkdir -p '" .. logdir .. "'")

local function start(name, cmd)
  hl.exec_cmd(apps.launch(cmd) .. " >'" .. logdir .. "/" .. name .. ".log' 2>&1")
end

hl.on("hyprland.start", function()
  start("wayle", "wayle panel start")
  start("walker", "walker --gapplication-service")
  start("cliphist", "wl-paste --watch cliphist store")
  -- With several monitors, write local/monitors.lua once (no-op afterwards).
  start("monitors", "dot-monitors")
end)

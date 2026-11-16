-- Programs started with the session. hypridle, hyprpolkitagent and
-- elephant (Walker's backend) run as systemd user services instead,
-- enabled by the installer (stage 70-services).
local apps = require("defaults")

hl.on("hyprland.start", function()
  hl.exec_cmd(apps.launch("wayle panel start"))
  hl.exec_cmd(apps.launch("walker --gapplication-service"))
  hl.exec_cmd(apps.launch("wl-paste --watch cliphist store"))
end)

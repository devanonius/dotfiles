-- Keybinds. Apps come from defaults.lua; everything is launched through uwsm.
local apps = require("defaults")
local run = function(cmd) return hl.dsp.exec_cmd(apps.launch(cmd)) end
local mod = "SUPER"

-- Apps
hl.bind(mod .. " + RETURN", run(apps.terminal))
hl.bind(mod .. " + SPACE", run(apps.launcher))
hl.bind(mod .. " + E", run(apps.fileManager))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | walker --dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + ESCAPE", run("dot-power-menu"))
hl.bind(mod .. " + CTRL + L", run(apps.locker))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("dot theme next"))
hl.bind(mod .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("dot-theme-picker"))

-- Windows
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Focus and move with the arrow keys
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- Workspaces 1-10 (key 0 is workspace 10)
for i = 1, 10 do
  local key = tostring(i % 10)
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

-- Screenshots: region / whole screen, to the clipboard and ~/Pictures/Screenshots
local shot = 'mkdir -p ~/Pictures/Screenshots && f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png && '
hl.bind("PRINT", hl.dsp.exec_cmd(shot .. 'grim -g "$(slurp)" "$f" && wl-copy < "$f"'))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shot .. 'grim "$f" && wl-copy < "$f"'))

-- Media, volume and brightness keys (work on the lock screen too; Wayle shows the OSD)
local media = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), media)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), media)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), media)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })

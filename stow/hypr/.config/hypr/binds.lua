-- Keybinds. Apps come from defaults.lua; everything is launched through uwsm.
-- Every bind has a description: SUPER+K lists them (dot-keybinds reads
-- `hyprctl binds -j`), so the cheat sheet always matches this file.
local apps = require("defaults")
local run = function(cmd) return hl.dsp.exec_cmd(apps.launch(cmd)) end
local mod = "SUPER"

-- bind(keys, dispatcher, description, extra flags)
local function bind(keys, dispatcher, description, flags)
  local opts = { description = description }
  for k, v in pairs(flags or {}) do opts[k] = v end
  hl.bind(keys, dispatcher, opts)
end

-- Apps
bind(mod .. " + RETURN", run(apps.terminal), "Terminal")
bind(mod .. " + SPACE", run(apps.launcher), "App launcher")
bind(mod .. " + E", run(apps.fileManager), "File manager")
bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | walker --dmenu | cliphist decode | wl-copy"), "Clipboard history")
bind(mod .. " + ESCAPE", run("dot-power-menu"), "Power menu (lock, suspend, log out, reboot, shut down)")
bind(mod .. " + CTRL + L", run(apps.locker), "Lock the screen")
bind(mod .. " + K", hl.dsp.exec_cmd("dot-keybinds"), "This list of keybinds")

-- Themes
bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("dot theme next"), "Next theme")
bind(mod .. " + CTRL + SHIFT + SPACE", hl.dsp.exec_cmd("dot-theme-picker"), "Theme picker")
bind(mod .. " + CTRL + SPACE", hl.dsp.exec_cmd("dot background next"), "Next wallpaper of the theme")

-- Windows
bind(mod .. " + Q", hl.dsp.window.close(), "Close window")
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Toggle fullscreen")
bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + J", hl.dsp.layout("togglesplit"), "Toggle split direction")
bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window (drag)", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window (drag)", { mouse = true })

-- Focus and move with the arrow keys
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }), "Focus window " .. dir)
  bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }), "Move window " .. dir)
end

-- Workspaces 1-10 (key 0 is workspace 10)
for i = 1, 10 do
  local key = tostring(i % 10)
  bind(mod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }), "Go to workspace " .. i)
  bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }), "Move window to workspace " .. i)
end
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace (scroll)")
bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "Previous workspace (scroll)")
bind(mod .. " + S", hl.dsp.workspace.toggle_special("scratch"), "Show/hide the scratchpad")
bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }), "Move window to the scratchpad")

-- Screenshots: region / whole screen, to the clipboard and ~/Pictures/Screenshots
local shot = 'mkdir -p ~/Pictures/Screenshots && f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png && '
bind("PRINT", hl.dsp.exec_cmd(shot .. 'grim -g "$(slurp)" "$f" && wl-copy < "$f"'), "Screenshot of a region")
bind("SHIFT + PRINT", hl.dsp.exec_cmd(shot .. 'grim "$f" && wl-copy < "$f"'), "Screenshot of the screen")

-- Media, volume and brightness keys (work on the lock screen too; Wayle shows the OSD)
local media = { locked = true, repeating = true }
local locked = { locked = true }
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", media)
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Volume down", media)
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute", locked)
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mute microphone", locked)
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), "Brightness up", media)
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), "Brightness down", media)
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), "Next track", locked)
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), "Previous track", locked)
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause", locked)
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), "Play/pause", locked)

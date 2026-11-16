-- Keyboard, mouse and touchpad. Keyboard layout is per machine:
-- set it in local/input.lua, e.g. hl.config({ input = { kb_layout = "se" } })
hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- Three-finger horizontal swipe switches workspaces.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

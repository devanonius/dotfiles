-- Gaps, borders, rounding, blur and the tiling layout.
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 2,
    resize_on_border = true,
    layout = "dwindle",
  },
  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = { enabled = true, range = 8, render_power = 3 },
    blur = { enabled = true, size = 4, passes = 2 },
  },
  dwindle = {
    preserve_split = true,
  },
  misc = {
    disable_hyprland_logo = true,
    force_default_wallpaper = 0,  -- Wayle draws the wallpaper
  },
})

# Themes

One folder per theme: `themes/<id>/`.

- `colors.json`: a pywal colorscheme, applied with `wal --theme`. `special` holds
  background, foreground and cursor; `colors` holds color0 to color15 (the ANSI
  palette). Copy the values from the theme's upstream project; never invent them.
- `theme.json`: everything pywal does not know about: display `name`,
  `family` (groups variants), `variant` (`dark` or `light`, drives GTK's
  prefer-dark/light), Neovim `nvim_plugin` and `nvim_scheme`, and `source` (the
  upstream URL the colors came from).

Templates (`stow/wal/.config/wal/templates/`) only use pywal's variables, so
every theme maps UI roles to the same palette slots:

| Role | Slot |
| --- | --- |
| background, text | background, foreground |
| accent / second accent | color4 / color5 |
| borders, muted text, inactive | color8 |
| raised surfaces (cards, popups) | color0 |
| secondary text (Wayle fg-muted) | color7 |
| error / warning / success | color1 / color3 / color2 |

Wallpapers go in `backgrounds/<id>/` at the repo root.

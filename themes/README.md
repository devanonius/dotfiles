# Themes

One folder per theme: `themes/<id>/`.

- `colors.json`: a pywal colorscheme, applied with `wal --theme`. `special` holds
  background, foreground and cursor; `colors` holds color0 to color15 (the ANSI
  palette). Copy the values from the theme's upstream project; never invent them.
- `theme.json`: everything pywal does not know about: display `name`,
  `family` (groups variants), `variant` (`dark` or `light`, drives GTK's
  prefer-dark/light), Neovim `nvim_plugin` and `nvim_scheme`, and `source` (the
  upstream URL the colors came from).

`colors.json` also carries the UI roles in `special`, taken from the theme's
upstream UI palette (its Neovim or editor theme), because the ANSI slots mean
different things in dark and light themes (on Catppuccin Latte `color0` is
dark text, not a surface). pywal passes every `special` key to the templates.

| Key in `special` | Role | Used for |
| --- | --- | --- |
| background, foreground, cursor | base | everything |
| surface | raised surfaces | bar pills, Walker, GTK cards/popovers/sidebars |
| elevated | surfaces above those | Wayle "elevated", btop meters |
| border | borders, separators | inactive window border, btop boxes |
| muted | secondary text (at least 3:1 on background) | Wayle fg-muted, Walker hints, hyprlock |
| accent / accent2 | main and second accent | active border gradient, highlights, active workspace |
| selection | selected text/rows | Ghostty, btop |

`color0`–`color15` stay the terminal's ANSI palette (Ghostty, and every CLI
tool themed with ANSI colors). Error/warning/success use `color1`/`color3`/`color2`.

Rules, checked by `tests/run.sh`: every value is `#rrggbb`; every key above
exists; foreground reaches 4.5:1 and muted 3:1 against background. Copy values
from upstream and name the files in `source`; never invent or eyeball them.
New theme from one of Ghostty's built-in palettes: `tools/import-ghostty-theme
"<Ghostty name>" <id>`, then fill the UI roles from the upstream project.
Themes without a Neovim plugin set `nvim_plugin` to `""`: habamax is built
into Neovim, Esmerald's colorschemes live in `stow/nvim/.config/nvim/colors/`
(generated from its VS Code theme, MIT notice inside).

Wallpapers go in `backgrounds/<id>/` at the repo root (see `backgrounds/README.md`).

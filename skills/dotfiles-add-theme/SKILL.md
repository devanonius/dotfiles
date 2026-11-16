---
name: dotfiles-add-theme
description: Use when adding, importing or fixing a color theme in the Hyprland dotfiles repo (themes/ID/colors.json + theme.json), e.g. Tokyo Night, Gruvbox, Catppuccin variants.
---

# Add or fix a theme

A theme is one folder `themes/<id>/` with two files (format: `themes/README.md`):

- `colors.json`: a pywal colorscheme, `{"special": {background, foreground, cursor}, "colors": {color0 .. color15}}`, applied with `wal --theme`.
- `theme.json`: `name`, `family`, `variant` (`dark` | `light`), `nvim_plugin`, `nvim_scheme`, `source`.

Wallpapers go in `backgrounds/<id>/` at the repo root, added by the owner by hand; nothing may fail on an empty folder.

## Rules

1. **Never invent colors.** Copy every value from the theme's upstream project (its palette file or its terminal ports, e.g. `extras/ghostty`). Put the upstream URL in `theme.json` `source`.
2. **Theme id** is lowercase kebab-case `<family>-<variant>` (e.g. `catppuccin-mocha`) and matches the folder name.
3. **All 19 colors**, `#rrggbb`, lowercase: background, foreground, cursor, color0-15. color0-15 are the theme's ANSI terminal palette, in ANSI order.
4. **Role mapping is fixed** (templates rely on it): accent = color4, second accent = color5, borders/muted = color8, raised surfaces = color0. If a theme's color4 is not its natural accent, that is still correct: do not reorder the ANSI palette to suit the UI.
5. **Contrast check** (WCAG relative luminance, compute it, do not eyeball): foreground vs background >= 4.5:1, color8 vs background >= 3:1. If upstream fails, keep upstream values and note it in the commit.
6. **Light variants** set `"variant": "light"`; GTK switches to prefer-light automatically.

## Fast path: seed from Ghostty

`ghostty +list-themes --plain | grep -i <name>` finds a built-in theme; its file under `/usr/share/ghostty/themes/` has background, foreground, cursor-color and palette 0-15, which map 1:1 onto `colors.json`. Fill `theme.json` by hand.

## Themes without a Neovim port (e.g. Esmerald)

Port from the upstream source (e.g. a VS Code theme JSON) into `stow/nvim/.config/nvim/colors/<id>.lua`, set `"nvim_plugin": ""`, and keep the upstream license notice at the top of every derived file.

## Done when

- `bash tests/run.sh --static` passes (validates metadata and renders every template with every theme).
- `dot theme set <id>` works and `git status` shows no changed tracked files.
- `dot theme list` shows it. Then run the `dotfiles-verify` skill before committing.

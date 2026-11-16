---
name: dotfiles-add-theme
description: Use when adding, importing or fixing a color theme palette (themes/ID/colors.toml) in the Hyprland dotfiles repo, e.g. Tokyo Night, Gruvbox, Catppuccin variants.
---

# Add or fix a theme palette

A theme is one directory `themes/<id>/` containing `colors.toml` (required) and optional `overrides/`. Wallpapers live in `backgrounds/<id>/` at the repo root and are added by the owner by hand; never fail on an empty folder. Every app is rendered from `colors.toml`, so a wrong value shows up everywhere.

## Rules

1. **Never invent colors.** Every value comes from the theme's upstream project (its palette file, or its `extras/` terminal ports). Put the source URL and upstream commit/tag in a comment on line 1 of `colors.toml`.
2. **Theme id** is lowercase kebab-case `<family>-<variant>` (e.g. `catppuccin-mocha`), unique, and matches the directory name.
3. **Full key set.** `[meta]`: name, family, variant (dark|light), nvim_plugin, nvim_scheme; optional btop_name, icon_theme. `[colors]`: background, foreground, surface, elevated, muted, border, accent, accent_alt, cursor, selection_bg, selection_fg, red, green, yellow, blue, magenta, cyan, orange, color0..color15. All `#rrggbb`, lowercase.
4. **Semantic keys** (surface, elevated, muted, border, accent) map to the upstream theme's own UI roles (e.g. tokyonight `bg_dark`, `bg_highlight`, `comment`), not to arbitrary ANSI slots.
5. **Contrast:** foreground vs background >= 4.5:1, muted vs background >= 3:1, selection_fg vs selection_bg >= 4.5:1. Compute with the WCAG relative-luminance formula (write a tiny python check, do not eyeball). If upstream fails, keep upstream values and note it in the comment.
6. **Light variants** set `variant = "light"` and a light `icon_theme`.

## Fast path: seed from Ghostty

`ghostty +list-themes --plain | grep -i <name>` to find a built-in theme, then `tools/import-ghostty-theme <ghostty-name> <id>` to fill background, foreground, cursor, selection and color0..15. Fill the semantic keys and `[meta]` by hand from upstream.

## Themes without a Neovim port (e.g. Esmerald)

Port from the upstream source (e.g. a VS Code theme JSON) into `stow/nvim/.config/nvim/colors/<id>.lua`, set `nvim_plugin = ""`, and keep the upstream license notice at the top of every derived file.

## Neovim mapping

`nvim_plugin` must be declared in `stow/nvim/.config/nvim/lua/plugins/theme.lua` (lazy = true). Confirm `nvim_scheme` exists: `nvim --headless "+colorscheme <scheme>" +qa` exits 0 after `Lazy! sync`.

## Done when

- `dot-theme-render <id>` succeeds with no unknown-key errors.
- `dot theme set <id>` then `dot doctor` passes.
- Theme appears in `dot theme list` under its family, and in the Walker picker.
- Then run the `dotfiles-verify` skill before committing.

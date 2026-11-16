---
name: dotfiles-add-themed-app
description: Use when bringing a new application (or an existing one) under the Hyprland dotfiles theme system: Stow package, template, include path, reload hook, doctor check.
---

# Add a themed application

Every themed app follows the same five-part contract. Do all five; a partial integration leaves the theme switch half-applied.

## 1. Research the app first

Before writing anything, confirm from the installed version (`<app> --help`, man page, upstream docs for that version):
- config file path and format;
- whether it supports including another file (and include order / precedence);
- whether it hot-reloads, and how to trigger a reload (signal, IPC, CLI) without losing state.
Record findings in the commit message. If the docs and the binary disagree, the binary wins.

## 2. Stow package (static config)

`stow/<app>/` mirrors `$HOME` (e.g. `stow/<app>/.config/<app>/config`). Files directly in `$HOME` use Stow's `dot-` prefix (`stow/zsh/dot-zshrc` -> `~/.zshrc`). Hand-written, tracked, contains no colors. It must include the rendered file from the fixed path `~/.local/state/dotfiles/theme/current/<file>`. Never point at `themes/` and never write generated output into `stow/`. Deploy with `dot restow`.

If the app cannot include files, symlink the app's color file location to the rendered file (created by the installer, untracked) rather than templating the whole config.

## 3. Template

`templates/<file>.tpl`. Placeholders: `{{ key }}` (#rrggbb), `{{ key.hex }}`, `{{ key.rgb }}`, `{{ key.rgba(a) }}`, `{{ key.hypr }}`, `{{ meta.<field> }}`. Use only keys from the palette schema; prefer semantic keys (accent, surface, muted) over ANSI slots so every theme looks intentional. If the app has its own token list (e.g. a schema.json), cover every token.

## 4. Reload hook

Add one entry to the hook list used by `dot-theme-set`: a single command, 2 s timeout, never fatal. Prefer live reload (signal/IPC) over restart; restart only long-running services, never kill user-facing windows.

## 5. Doctor + docs

- `dot doctor`: check the rendered file exists and the app's own validator passes, if it has one.
- Add a row to the Per-application table in docs/SPEC.md (template, include path, reload hook).
- Add the package to the right `packages/*.txt`.

## Done when

Switching between a dark and a light theme visibly changes the app, `git status` shows no modified tracked files after the switch, and the `dotfiles-verify` skill passes.

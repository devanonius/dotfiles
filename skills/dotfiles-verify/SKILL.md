---
name: dotfiles-verify
description: Use before every commit in the Hyprland dotfiles repo, or when asked to check or validate it: lint, dry-run, config validation, renderer tests, idempotency.
---

# Verify the dotfiles repo

Run the checks in order and stop at the first failure; fix it, then restart from step 1. Report each step's result, and say explicitly which steps could not run (e.g. no Hyprland session in a container) instead of claiming they passed.

## Static checks (run anywhere)

1. `shellcheck -x install.sh bin/dot lib/*.sh lib/install/*.sh` (plus `migrations/*.sh` once it exists) -- zero warnings, or a justified `# shellcheck disable=` with a reason comment.
2. `bash -n` on every script (syntax).
3. Renderer tests (from phase 3): `python3 -m unittest discover -s tests` -- covers every placeholder modifier, an unknown key failing with template name + line, and rendering every theme in `themes/`.
4. Every `themes/*/colors.toml` parses with `tomllib` and has the full key set; contrast thresholds hold (see dotfiles-add-theme).
5. No generated files tracked: `git ls-files` contains nothing under a rendered theme dir, no `*.log`, nothing machine-local.
6. Package names resolve: `dot packages check` (skip if offline or not on Arch, and say so).

## System checks (on an Arch machine)

7. `stow -n -v --no-folding -d stow -t "$HOME" <pkg>` for every package -- no conflicts.
8. `./install.sh --dry-run` -- lists actions, exits 0. Then a real run, then a second real run: the second must print "Nothing to do" (idempotency).
9. `ghostty +validate-config` passes.
10. Inside a Hyprland session: `hyprctl reload` then `hyprctl configerrors` is empty.
11. `nvim --headless "+Lazy! sync" +qa` exits 0; `nvim --headless +qa` starts without errors.
12. Theme round trip: `dot theme set` to a dark theme, then a light theme, then back; after each, `dot doctor` passes and `git status --porcelain` is empty.

## Commit

Only after all runnable steps pass. One logical change per commit; message says what changed and which checks ran.

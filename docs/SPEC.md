# Hyprland Dotfiles: Implementation Spec

Living document: https://claude.ai/artifact/6Y8JbG131CKdkFhVSbtsn2 (exported 2026-11-16)

## How to use this spec

Build a git-managed dotfiles repo that turns a minimal Arch install, or an existing Hyprland setup, into a fully riced Hyprland desktop with one command, and switches every app's colors with one theme command, Omarchy-style.

This document is written for an implementing LLM. Treat every "must" as a requirement and every "verify" as a fact to check against upstream docs or `--help` output before writing code, because several tools here (Wayle, Walker, Hyprland gesture syntax) change quickly.

**Goals**

- One idempotent installer: safe to re-run at any time, on a fresh or an existing system.
- Every config lives in the repo and is edited in place; `git pull` / `git commit` / `git push` is the whole sync workflow.
- A theme system where one palette file per theme drives Hyprland, Ghostty, the shell, Wayle, Walker, LazyVim, GTK, btop and hyprlock, with live reload where the app supports it.
- Hardware support for laptops, desktops, Nvidia GPUs and multiple monitors through detected, machine-local overrides.

**Non-goals**

- Installing Arch itself (partitioning, bootloader, users). The installer starts from a booted system with network and a sudo user.
- Managing secrets, SSH keys or GPG keys.
- Supporting distros other than Arch, or compositors other than Hyprland.

## Decisions and constraints

Configs are deployed with GNU Stow, orchestrated by a small bash installer; generated theme output never lands in the repo.

**Why Stow over a pure custom script.** Both keep the repo fully git-driven, because both symlink files back into the repo, so an in-place edit is immediately a `git diff`. Stow's footprint is one small package (`stow`, a Perl script; Perl is already pulled in by `git`). A custom script avoids that dependency but must re-implement conflict detection, unlinking and cleanup of removed files, which Stow already does. The installer stays custom bash for everything Stow does not do: packages, services, themes, hardware.

| Topic | Decision |
| --- | --- |
| Deployment | `stow --no-folding --target=$HOME` per package, so only files are symlinked and apps that write new files into `~/.config/<app>/` never pollute the repo |
| Repo location | `$DOTFILES_DIR`, default `~/dotfiles`; every script resolves paths from it |
| Start states | Fresh minimal Arch (no desktop) and an existing Hyprland system, both handled by the same idempotent installer |
| Hardware | Laptop, desktop, Nvidia, multi-monitor; detected at install time, written to untracked machine-local files |
| Launcher | Walker |
| Status bar, notifications, OSD, wallpaper | Wayle |
| Terminal and shell | Ghostty, zsh, Oh My Zsh, Powerlevel10k |
| Editor | Neovim with LazyVim |
| AUR helper | yay (bootstrapped from `yay-bin`) |
| Theme renderer | Python 3 standard library only (`tomllib`), no third-party modules |
| Generated output | `~/.local/state/dotfiles/` (themes, backups, migration state), never committed |

**Owner decisions, 2026-11-15** (these override anything older in this document):

- **Hyprland 0.55 or newer, configured only in Lua.** Lua config arrived in 0.55 and 0.57 removed `hyprland.conf` support, so there is no hyprlang fallback. The config is split into logical files (see Per-application configuration).
- **No default greeter.** archinstall lets the user pick a display manager (the owner's machine uses cosmic-greeter), so the installer keeps whatever is enabled. Config key `greeter`: `"keep"` (default) or a package name to install and enable. With no display manager enabled, log in on tty1 and start Hyprland through `uwsm` from `.zprofile`.
- **Replaced packages** never install from module or hardware lists (`packages/exclude.txt`): dunst (Wayle does notifications), wofi (Walker), polkit-kde-agent (hyprpolkitagent), iwd (NetworkManager, which Wayle needs), eza (lsd).
- **Hardware packages are detected, fonts are picked.** CPU microcode and GPU drivers come from `packages/hardware/`; Nerd Fonts from a pick-list (`fonts` config key, `dot fonts`).
- **Build as little as possible.** Prefer existing tools (pywal16 for theming, Stow for links) and only fill the gaps. AUR packages are always the prebuilt -bin variant when one exists (2026-11-16: a test install spent 30 minutes compiling); stage 30-yay swaps in -bin variants for listed packages and their AUR dependencies and warns about anything it must still build.
- **Keep Arch-specific code separate.** pacman, yay and package lists live in their own stages; linking, theming and config files must not depend on them, so they can be reused on another distro later.
- **Wallpapers** live in `backgrounds/<theme-id>/` at the repo root (the owner adds them by hand), not in `themes/<id>/backgrounds/`.

**Git workflow rules**

- Tracked: every hand-written config, theme palettes, templates, package manifests, scripts, `lazy-lock.json`, `.p10k.zsh`.
- Untracked (in `.gitignore` or outside the repo): rendered theme files, `~/.config/hypr/local/*`, backups, caches.
- Tools that rewrite their own config (Wayle's settings GUI, `p10k configure`, Lazy updates) write through the symlink, so their changes show up as normal diffs to commit or discard.
- `dot update` = `git pull --rebase`, then re-run the installer, so pulling on a second machine converges it.

## Repository layout

The repo splits into Stow packages (static configs), the theme system (palettes plus templates), and scripts; nothing under `stow/` is generated.

```text
dotfiles/
├── bootstrap.sh               # curl-run entry: installs git, clones, runs install.sh
├── install.sh                 # runs lib/install/NN-*.sh in order
├── bin/dot                    # user CLI (install, update, restow, fonts, packages, theme ...)
├── config/
│   ├── default.json           # what gets installed by default
│   ├── example.json
│   └── config.schema.json     # editor validation for config files
├── lib/
│   ├── common.sh  detect.sh  config.sh  config-validate.jq
│   └── install/               # 00-preflight 05-config 10-detect 20-pacman 25-fonts
│                              # 30-yay 35-flatpak 50-stow (later: shell, system, services, theme)
├── packages/
│   ├── base.txt  aur.txt      # always
│   ├── desktop.txt  user.txt  # modules (any packages/<name>.txt is a module)
│   ├── exclude.txt            # never installed from lists (replaced by the rice)
│   ├── hardware/              # cpu-intel cpu-amd gpu-intel gpu-amd gpu-nvidia laptop
│   └── fonts/nerd-fonts.txt   # font picker catalog
├── stow/                      # one folder per app, mirrors $HOME, linked file by file
│   ├── hypr/.config/hypr/hyprland.lua + binds.lua monitor.lua defaults.lua
│   │                          #   layout.lua animations.lua rules.lua autostart.lua ...
│   ├── ghostty/  zsh/  wayle/  walker/  nvim/  git/  btop/  gtk/  wal/
├── system/                    # copied to / with sudo, not linked (e.g. system/keyd -> /etc/keyd)
├── themes/<id>.json           # pywal16 colorschemes (+ small per-theme overrides)
├── backgrounds/<id>/          # wallpapers per theme, added by hand
├── skills/                    # LLM skills; copy to .claude/skills
├── tests/run.sh  docker.sh  ci.json
├── tools/generate-user-list.sh
└── docs/SPEC.md  README.md
```

Runtime paths outside the repo:

- `~/.local/state/dotfiles/theme/current` → symlink to the active rendered theme directory.
- `~/.local/state/dotfiles/backup/<timestamp>/` → files moved aside before stowing.
- `~/.local/state/dotfiles/migrations.done` → list of applied migrations.
- `~/.config/hypr/local/` → machine-local Hyprland includes (monitors, hardware env), never tracked.

## Installer design

`install.sh` runs numbered stages in order; each stage checks state before acting, so a second run on a converged machine changes nothing.

1. `00-preflight` — refuse to run as root; require Arch (`/etc/arch-release`), network, and sudo. Cache sudo credentials and keep them alive for the run.
2. `10-detect` — source `lib/detect.sh` and export `IS_LAPTOP` (any `/sys/class/power_supply/BAT*`), `HAS_NVIDIA` (`lspci` shows an NVIDIA VGA/3D device), `HAS_HYPRLAND` (`pacman -Q hyprland`), and the monitor count once a session exists (`hyprctl monitors -j`).
3. `20-pacman` — `pacman -Syu --needed` with `base.txt` + `desktop.txt`, plus `laptop.txt` / `nvidia.txt` when detected, plus `user.txt` when present.
4. `30-yay` — if `yay` is missing: clone `https://aur.archlinux.org/yay-bin.git` into a temp dir, `makepkg -si --noconfirm`. Then `yay -S --needed` from `aur.txt`.
5. `40-shell` — install Oh My Zsh unattended into `~/.oh-my-zsh` (`RUNZSH=no KEEP_ZSHRC=yes`), clone Powerlevel10k, zsh-autosuggestions and zsh-syntax-highlighting into `$ZSH_CUSTOM`; `git pull` them if already present. `chsh -s /usr/bin/zsh` only if not already the login shell.
6. `50-stow` — for each package in `stow/`: dry-run (`stow -n -v`), move any conflicting real file to the backup dir, then `stow --restow --no-folding`. Never use `--adopt`, because it overwrites repo files with whatever is on disk.
7. `60-hardware` — write `~/.config/hypr/local/{env,monitors,input}.conf` from detection results, only if each file does not exist yet (user edits win).
8. `70-services` — enable `NetworkManager`, `bluetooth`, `upower`, `power-profiles-daemon` (Wayle depends on these), PipeWire user units, and the chosen login method.
9. `80-theme` — run `dot-theme-set` with the current theme, or the default theme on first install.
10. `90-migrations` — run every `migrations/*.sh` not listed in `migrations.done`, append each on success.

**Flags:** `--dry-run` (print actions only), `--only <stage>`, `--skip <stage>`, `--no-packages` (configs only, for existing systems where the owner manages packages), `--yes` (non-interactive).

**Install config (`-c/--config FILE`, implemented in phase 1).** A JSON file chooses what is installed. `config/default.json` (tracked) is overlaid by `~/.config/dotfiles/config.json` (per machine, untracked) and then by the `-c` file; objects merge, lists replace. Keys: `modules` (each key names `packages/<key>.txt`, value `true`, `false` or `"auto"`; `base` and `aur` are always installed), `extra_packages` (`pacman`, `aur`, `flatpak` lists), and `flatpak` (`scope` user or system, `remote`, `remote_url`). Stage `05-config` validates every file with `lib/config-validate.jq` (mirrored by `config/config.schema.json` for editors) and fails with all problems listed. Stage `35-flatpak` installs flatpak and its remote only when the flatpak list is non-empty. Later phases add their options to this file (e.g. module switches for keyd, browser choice) rather than new prompts.

**Implemented so far (phases 1–2):** stages `00-preflight`, `05-config`, `10-detect`, `20-pacman` (modules + detected hardware lists − `exclude.txt` + `extra_packages.pacman`), `25-fonts`, `30-yay`, `35-flatpak`, `40-shell` (zsh as login shell, git identity prompt), `50-stow` (also links every `bin/*` script into `~/.local/bin`), `70-services` (NetworkManager, bluetooth, upower, power-profiles-daemon; user units hypridle, hyprpolkitagent, elephant; greeter kept unless `greeter` names one); config keys `modules`, `hardware`, `fonts`, `greeter`, `extra_packages`, `flatpak`; Stow packages `hypr` (Lua), `ghostty`, `zsh`, `wayle`, `git`; `tests/run.sh` and `tests/docker.sh`. Walker runs on its defaults until the phase 3 theme. Oh My Zsh (`oh-my-zsh-git`, AUR) `is a package, so it updates with the system; Powerlevel10k is not in the Arch repos, so stage 40-shell clones it into $ZSH_CUSTOM/themes/powerlevel10k (its README's Oh My Zsh method) and pulls updates on every run`; zsh plugins come from the repos and are sourced directly. The prompt uses Powerlevel10k's shipped lean style until a committed `.p10k.zsh` (ANSI colors, phase 3) replaces it.

**Curl-run bootstrap and module selection (to build).** The owner wants at most to curl-run one script and pick what to install:

1. `bootstrap.sh`, fetched with `curl -fsSL <raw-url>/bootstrap.sh | bash` (also accepts `-- -c URL-or-file`): installs `git` with pacman, clones the repo to `$DOTFILES_DIR` (default `~/dotfiles`) or pulls if it exists, then runs `install.sh` with the remaining arguments. It must work from a pipe, so every prompt reads from `/dev/tty`.
2. When no `-c` is given and `~/.config/dotfiles/config.json` does not exist, `install.sh` shows a module menu on the terminal (a checklist of modules: desktop, user, keyd, browser, flatpak extras, fonts) and saves the answers to `~/.config/dotfiles/config.json`, so later runs and `dot update` do not ask again. Without a terminal or with `--yes`, it uses `config/default.json`.
3. The menu must not need packages that are not installed yet: plain bash (`read -r </dev/tty`), not fzf or gum.

**Fresh vs existing system:** the same stages run in both cases. On an existing Hyprland system the difference is only that `50-stow` backs up the current `~/.config/hypr` and friends first, and `70-services` skips the login method if a display manager is already enabled.

**Logging:** every run tees to `~/.local/state/dotfiles/logs/install-<timestamp>.log`; a failed stage stops the run with the stage name and log path.

## Package manifests

Manifests are plain text, one package per line, `#` comments allowed; the lists below are the minimum the rice needs, and the owner's full list goes in `packages/user.txt` later.

| Path | Installed by | When |
| --- | --- | --- |
| `base.txt` | pacman | always: build tools, git, stow, python, zsh, fzf, bat, lsd, zoxide, jq, Neovim + LazyVim deps, btop |
| `desktop.txt` | pacman | module `desktop`: Hyprland stack, uwsm, portals, Ghostty, PipeWire, NetworkManager, bluez, upower, power-profiles-daemon, screenshot/clipboard tools, GTK/Qt theming, JetBrains Mono Nerd + Noto fonts |
| `user.txt` | pacman | module `user`: the owner's own apps, rebuilt with `tools/generate-user-list.sh` (leaves out what other lists cover, replaced packages, kernel and bootloader) |
| `hardware/cpu-intel.txt`, `cpu-amd.txt` | pacman | CPU vendor detected: microcode |
| `hardware/gpu-intel.txt`, `gpu-amd.txt`, `gpu-nvidia.txt` | pacman | GPU vendor detected: VA-API / Vulkan drivers (NVIDIA filled in phase 6) |
| `hardware/laptop.txt` | pacman | battery detected |
| `fonts/nerd-fonts.txt` | pacman | catalog for the `fonts` setting / picker |
| `exclude.txt` | — | never: removed from every module and hardware list |
| `aur.txt` | yay | always (Walker, Wayle and other AUR packages, names verified in phase 2) |
| config `extra_packages` | pacman / yay / flatpak | per config file; never filtered by `exclude.txt` |

Rules for the implementer:

- Verify every package name with `pacman -Si` / `yay -Si` before committing a manifest; drop or rename anything that fails, and note it in the PR.
- Nerd Fonts: install the specific `ttf-*-nerd` packages rather than the whole `nerd-fonts` group (several GB). JetBrains Mono Nerd is the default terminal font.
- Wayle: upstream documents building with `cargo install --path wayle` and `--path crates/wayle-settings`, then `wayle icons setup`. If no AUR package exists, stage `30-yay` builds from a pinned git tag into `~/.cargo/bin` and needs `rust` in `base.txt`.
- Package removal is out of scope: deleting a line from a manifest does not uninstall the package.

## Theme engine

pywal16 is the theme engine (implemented in phase 3): `dot theme set <id>` runs `wal --theme themes/<id>/colors.json`, which renders the tracked templates in `stow/wal/.config/wal/templates/` into `~/.cache/wal/` and recolors open terminals; apps read their file from there, so switching never edits a tracked file.

&#91;embedded content: theme switch pipeline · 3 inputs, 1 render, 1 swap, 7 consumers\]

A switch never edits a tracked file: the renderer writes a fresh directory, the `current` symlink flips to it, and each app reloads from the same fixed path.

**How it is built (phase 3).** Decided 2026-11-15: use pywal16 instead of a custom renderer, so the repo relies on an existing, maintained tool.

- **Theme files:** `themes/<id>/colors.json` (pywal colorscheme: `special` background/foreground/cursor, `colors` color0–color15) and `themes/<id>/theme.json` (`name`, `family`, `variant` dark|light, `nvim_plugin`, `nvim_scheme`, `source`). Format and rules: `themes/README.md`.
- **Templates** use only pywal's variables (`{color0}`..`{color15}`, `{background}`, `{foreground}`, `{cursor}`, with `.strip`, `.rgb`, `.red/.green/.blue`). pywal fills them with Python `str.format`, so literal braces are doubled (`{{ }}`). UI roles map to fixed slots: accent color4, second accent color5, borders/muted color8, raised surfaces color0, error/warning/success color1/3/2.
- **`dot theme set`** (`lib/theme.sh`): `wal -q -n -e --theme …` (`-n`: Wayle owns the wallpaper; `-e`: no pywal reloads) → link the apps that cannot include a file → GTK `color-scheme` and `gtk-theme` from `variant` → reload hooks (2 s timeout, never fatal) → user hooks in `~/.config/dotfiles/hooks/theme-set.d/`. Also `dot theme list | current | next | prev`; `SUPER+SHIFT+T` = next.
- **Install stage `80-theme`** applies the active theme (default `tokyonight-night`) only when the theme or a template changed (fingerprint in `~/.local/state/dotfiles/theme/`).
- **Tests:** `tests/fake-wal.py` renders every template with every theme exactly as pywal does (fails on unescaped braces or unknown variables); the rendered Hyprland Lua is syntax-checked.
- **Still to verify on hardware:** whether `wayle config set styling.palette.<key> "#hex"` applies live (Wayle uses `theme-provider = "wayle"`; its `pywal` provider extracts colors from the wallpaper and ignores the theme); Walker's CSS class names; pywal16's package name `python-pywal16`.

The palette schema, template syntax and activation steps below describe the earlier custom-renderer design and are kept only for reference; where they differ, this section and `themes/README.md` win.

**Palette schema (`themes/<id>/colors.toml`).** All keys required unless marked optional; colors are `#rrggbb`.

```toml
[meta]
name        = "Tokyo Night Storm"
family      = "tokyonight"            # groups variants in the picker
variant     = "dark"                  # dark | light
nvim_plugin = "folke/tokyonight.nvim"
nvim_scheme = "tokyonight-storm"
btop_name   = "tokyo-storm"           # optional, else generated
icon_theme  = "Papirus-Dark"          # optional

[colors]
background   = "#24283b"
foreground   = "#c0caf5"
surface      = "#1f2335"   # panels
elevated     = "#292e42"   # popups
muted        = "#565f89"
border       = "#3b4261"
accent       = "#7aa2f7"
accent_alt   = "#bb9af7"
cursor       = "#c0caf5"
selection_bg = "#364a82"
selection_fg = "#c0caf5"
red = "#f7768e"
green = "#9ece6a"
yellow = "#e0af68"
blue = "#7aa2f7"
magenta = "#bb9af7"
cyan = "#7dcfff"
orange = "#ff9e64"
color0 = "#1d202f"   # ... color1 through color15 follow: the ANSI palette
# illustrative values; take real ones from the upstream theme's extras
```

**Template syntax.** `{{ key }}` → `#rrggbb`; `{{ key.hex }}` → `rrggbb`; `{{ key.rgb }}` → `r, g, b`; `{{ key.rgba(0.8) }}` → `rgba(r, g, b, 0.8)`; `{{ key.hypr }}` → `rgb(rrggbb)` for Hyprland; `{{ meta.<field> }}` for metadata. An unknown key is a hard error naming the template and line, never an empty string.

**Activation (`dot-theme-set <id>`).**

1. Take a lock (`flock` on `~/.local/state/dotfiles/theme.lock`) so two switches cannot interleave.
2. Create `theme/next/`, render every template into it, then copy `themes/<id>/overrides/*` on top (hand-written files beat templates).
3. Rename `next` to `theme/<id>-<timestamp>`, repoint the `current` symlink with `ln -sfn`, delete older renders except the previous one.
4. Write the theme id to `~/.local/state/dotfiles/theme/name`.
5. Run reload hooks (table in Per-application configuration), each with a 2 s timeout; a failing hook logs a warning and never aborts the switch.
6. Run user hooks in `~/.config/dotfiles/hooks/theme-set.d/*` with the theme id as `$1`.

**Consumption rule.** Apps never point at `themes/` directly. Each app's tracked config includes a fixed path under `~/.local/state/dotfiles/theme/current/`, so switching never edits a tracked file.

**Shell tools use the ANSI palette.** p10k, lsd, fzf, bat (`--theme=ansi`), lazygit and git colors are configured with ANSI color numbers 0–15, so they follow Ghostty's palette with no per-theme files.

## Theme catalog

Ship these 18 theme ids in v1; every palette value must be copied from the named upstream source, never invented or eyeballed.

| Theme id | Variant | Neovim plugin / colorscheme | Palette source |
| --- | --- | --- | --- |
| `habamax` | dark | built-in / `habamax` | Vim's `colors/habamax.vim` (GUI colors); derive the ANSI 16 from it |
| `tokyonight-night` | dark | `folke/tokyonight.nvim` / `tokyonight-night` | tokyonight.nvim `extras/ghostty` |
| `tokyonight-storm` | dark | same / `tokyonight-storm` | same |
| `tokyonight-moon` | dark | same / `tokyonight-moon` | same |
| `tokyonight-day` | light | same / `tokyonight-day` | same |
| `gruvbox-dark` | dark | `ellisonleao/gruvbox.nvim` / `gruvbox` (`background=dark`) | gruvbox upstream palette |
| `gruvbox-light` | light | same (`background=light`) | same |
| `catppuccin-mocha` | dark | `catppuccin/nvim` / `catppuccin-mocha` | catppuccin/palette |
| `catppuccin-macchiato` | dark | same / `catppuccin-macchiato` | same |
| `catppuccin-frappe` | dark | same / `catppuccin-frappe` | same |
| `catppuccin-latte` | light | same / `catppuccin-latte` | same |
| `onedark` | dark | `navarasu/onedark.nvim` / `onedark` (style `dark`) | onedark.nvim palette |
| `darcula` | dark | a maintained Darcula port (verify; e.g. `xiantang/darcula-dark.nvim`) | JetBrains Darcula scheme |
| `esmerald` | dark | no upstream port: repo-local `stow/nvim/.config/nvim/colors/esmerald.lua` | [esthorace/esmerald](https://github.com/esthorace/esmerald) VS Code theme JSON in `themes/` |
| `esmerald-light` | light | repo-local `colors/esmerald-light.lua` | same repo, Esmerald Light variant |
| `everforest-dark` | dark | `neanias/everforest-nvim` / `everforest` | everforest palette |
| `kanagawa-wave` | dark | `rebelot/kanagawa.nvim` / `kanagawa-wave` | kanagawa.nvim `extras` |
| `rose-pine` | dark | `rose-pine/neovim` / `rose-pine` | rose-pine palette |

The last three are extras the owner chose to keep for now. Default theme on first install: `tokyonight-night`.

**Esmerald port.** [Esmerald](https://github.com/esthorace/esmerald) is a VS Code theme (MIT) with a dark and a light variant, and has no terminal or Neovim port. Clone the repo, read both theme JSON files under `themes/`, and map them: `editor.background` → background, `editor.foreground` → foreground, `sideBar.background` / `editorWidget.background` → surface / elevated, `focusBorder` or the main accent → accent, `editor.selectionBackground` → selection\_bg, `editorCursor.foreground` → cursor, `terminal.ansi*` (16 keys) → color0–15. If the JSON has no `terminal.ansi*` keys, derive the ANSI 16 from its `tokenColors` and note that in the source comment. Then write `colors/esmerald.lua` and `colors/esmerald-light.lua` as small Neovim colorschemes from the same palette (editor UI groups, Treesitter and LSP groups mapped from `tokenColors`), and set `nvim_plugin = ""` so the theme spec loads no plugin. Keep the MIT notice in a comment at the top of each derived file.

**Seeding helper.** Ghostty ships hundreds of built-in themes (sourced from iterm2-color-schemes) under `/usr/share/ghostty/themes/`. Provide `tools/import-ghostty-theme <name> <id>` that reads one of those files and writes the ANSI palette, background, foreground, cursor and selection into a new `colors.toml`; the semantic keys (`surface`, `accent`, ...) are then filled by hand from the upstream project. Check names with `ghostty +list-themes --plain`.

**Light themes.** A `variant = "light"` theme must also flip GTK to `prefer-light` and pick a light icon theme; the renderer exposes `{{ meta.variant }}` for this.

## Per-application configuration

Each themed app gets a Stow package with its static config, one template, a fixed include path and a reload hook; the table is the contract, the notes below it are the app-specific requirements.

| App | Template → rendered file | How the tracked config consumes it | Reload hook |
| --- | --- | --- | --- |
| Hyprland | `colors-hyprland.lua (pywal16 template)` → `~/.cache/wal/colors-hyprland.lua (a Lua table of theme colo`rs) | `theme.lua loads ~/.cache/wal/colors-hyprland.lua inside pcall` | `hyprctl reload` |
| hyprlock | `hyprlock.conf.tpl` → `hyprlock.conf` | `source =` the same way | none (read at lock time) |
| Ghostty | `ghostty.conf.tpl` → `ghostty.conf` (`palette = N=#..`, bg, fg, cursor, selection) | `config-file = ?~/.local/state/dotfiles/theme/current/ghostty.conf` | `pkill -USR2 -x ghostty` |
| Wayle | `wayle.toml.tpl` → `~/.config/wayle/themes/dotfiles.toml` (real file, not stowed) | `config.toml` selects theme `dotfiles` permanently | verify whether Wayle hot-reloads theme files; else `wayle panel restart` (verify command) |
| Walker | `walker.css.tpl` → `style.css` in a `dotfiles` theme dir | `~/.config/walker/themes/dotfiles` → symlink to the rendered dir; `config.toml` sets `theme = "dotfiles"` | restart the Walker service (verify unit name) |
| Neovim | `nvim.lua.tpl` → `nvim.lua` returning `{ plugin, scheme, background }` | `lua/plugins/theme.lua` reads it at startup | send `:lua require('dotfiles.theme').reload()` to each socket in `$XDG_RUNTIME_DIR/nvim.*` |
| GTK 3/4 | `gtk.css.tpl` → `gtk.css` (libadwaita `@define-color` accent and view colors) | `~/.config/gtk-{3,4}.0/gtk.css` symlinked to rendered file | `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` or `prefer-light` |
| btop | `btop.theme.tpl` → `dotfiles.theme` | `btop.conf`: `color_theme = "dotfiles"`, theme file linked into `~/.config/btop/themes/` | `pkill -USR2 btop` (verify) |
| Qt (phase 7) | `qt6ct.conf.tpl` → color scheme | `QT_QPA_PLATFORMTHEME=qt6ct` | none |

**Hyprland (Lua only).** The entry point is `~/.config/hypr/hyprland.lua`; it only loads the other files with `require()`, which Hyprland resolves relative to that file and runs as separate scopes, so an error in one file does not stop the rest. One file per logical unit:

| File | Holds |
| --- | --- |
| `defaults.lua` | the user's preferred apps (terminal, browser, file manager, editor, launcher) as variables the other files use |
| `monitor.lua` | monitor layout defaults (machine-specific layout goes in `local/monitors.lua`) |
| `binds.lua` | all keybinds (see Commands and keybinds) |
| `layout.lua` | gaps, borders, layout choice and its options |
| `animations.lua` | animation curves and toggles |
| `rules.lua` | window and workspace rules |
| `input.lua` | keyboard, touchpad, gestures |
| `env.lua` | environment variables |
| `autostart.lua` | Wayle, Walker service, hyprpolkitagent, hypridle, `wl-paste --watch cliphist store`, all through `uwsm app --` |
| `theme.lua` | loads the pywal16-rendered colors (`~/.cache/wal/colors-hyprland.lua`) inside `pcall`, falling back to built-in colors if the file is missing |
| `local/*.lua` | untracked machine-local overrides (monitors, input, env), loaded last with `pcall(require, "local.<name>")` so a missing file is not an error |

Wherever this spec says `~/.config/hypr/local/*.conf`, read `local/*.lua`. Reload with `hyprctl reload` (saving also reloads). Verify the exact Lua API (`hl.*` functions, bind and rule syntax) against the wiki for the installed version, because the API is still growing; check `hyprctl` for config errors after every change. hypridle and hyprlock have their own config files: check whether they also moved to Lua before writing them.

**Ghostty.** Font `JetBrainsMono Nerd Font`, size 11, `window-decoration = false`, padding 8, `background-opacity` 0.95, `shell-integration = zsh`, `gtk-single-instance = true` for fast startup. Never set `theme =` in the tracked config: Ghostty loads `theme` before the user config, while `config-file` loads after it, so the include is what wins. Run `ghostty +validate-config` in the doctor.

**zsh.** `.zshrc` loads p10k instant prompt, then Oh My Zsh with plugins `git sudo fzf zoxide zsh-autosuggestions zsh-syntax-highlighting` (syntax-highlighting last), then `~/.config/zsh/{aliases,env,functions}.zsh`, then `~/.config/zsh/local.zsh` if present (untracked). Add `$DOTFILES_DIR/bin` to PATH. Commit a `.p10k.zsh` built with the "lean" style using ANSI colors 0–15 only. Note: Powerlevel10k upstream is in limited-maintenance mode; keep the prompt config isolated so swapping to another prompt later is one file.

**Wayle.** Upstream config is `~/.config/wayle/config.toml`, reloaded on save, and themes are TOML files in `~/.config/wayle/themes/` with tokens such as `bg`, `surface`, `elevated`, `fg`, `fg_muted`, `primary`, `red`, `yellow`, `green`, `blue`. Wayle writes a `themes/schema.json`; read it after first start for the full token list and make the template cover every token. Layout: left `dashboard`, workspaces, window title; center `clock`; right media, volume, network, bluetooth, battery (laptop only via local override), tray. Use Wayle for notifications, OSD and wallpaper too; per-theme wallpaper comes from `themes/<id>/backgrounds/` (verify the Wayle CLI or config key for setting wallpaper).

**Status bar requirements (owner).** These are required regardless of layout:

- **Active workspace:** a workspace indicator that clearly marks the active workspace (and which ones have windows).
- **Clock:** formatted in the user's locale by default (taken from `LC_TIME` / `LANG`); the format can be overridden in the install config (`statusbar.clock_format`) and written into Wayle's config at install time.
- **Battery:** a pie-chart (filling circle) battery button, shown only on laptops (battery detected); hidden on desktops.
- Cohesive and professional look: same font, spacing and accent as the rest of the theme; colors come from the active theme.

**Walker.** Bind `SUPER+SPACE` to the launcher. Provide dmenu-mode menus used by `dot-theme-picker`, a power menu and a clipboard menu (cliphist). Walker was rewritten with a separate `elephant` data backend; confirm the installed version's config format and theme directory before writing the template.

**LazyVim.** Commit the LazyVim starter into `stow/nvim` (without its `.git`). Add `lua/plugins/theme.lua` that declares every theme plugin in the catalog with `lazy = true` and sets LazyVim's `colorscheme` from the rendered `nvim.lua`, falling back to `tokyonight` if the file is missing. Commit `lazy-lock.json` so plugin versions are reproducible across machines.

**Git.** `~/.config/git/config` includes `~/.config/git/local` for name, email and signing key; the installer prompts once to create that local file.

## System files and keyd

Files that belong outside `$HOME` live in `system/<name>/` and are copied (not linked) by a later installer stage, `55-system`, because services such as keyd read them at boot, before a home folder may be available.

- `system/<name>/` m`irrors the root of the filesystem (implemented): system/keyd/etc/keyd/default.conf → /etc/keyd/default.conf. Units listed in system/<name>.service are enabled, and restarted when that module's files change`.
- Copy with `sudo install -D -m 644`; compare checksums first so an unchanged file is not copied again (idempotency) and a differing existing file is backed up to `~/.local/state/dotfiles/backup/<timestamp>/system/` before it is replaced.
- Each system folder is a module in the install config (`modules.keyd`), installed together with its package (`keyd` is in `packages/keyd.txt; the module is on by default`).
- After copying keyd files: `sudo systemctl enable --now keyd`, then `sudo keyd reload`. Validate the config first if keyd offers a check command (verify), so a typo cannot leave the keyboard unusable.
- Editing: the repo copy is the source of truth. `dot restow` (or the system stage) pushes changes to `/etc`; files changed directly in `/etc` are reported by `dot doctor` as drift instead of being overwritten silently.

## Browser and Qt theming (phase 7)

The installer asks which browser to use, installs it with Vimium through browser policy, and the theme system colors the browser UI and Vimium; this ships after the core six phases.

**Browser prompt.** New installer stage `25-browser`, run after packages and before Stow:

1. If `~/.config/dotfiles/local.toml` (untracked) already has `browser = "<id>"`, skip the prompt. Otherwise show a menu (`gum choose` if installed, else a numbered `select`), or take `--browser <id>` for non-interactive runs.
2. Choices and sources (verify each name with `pacman -Si` / `yay -Si`):

| Id | Browser | Package | Family | Policy directory (verify) |
| --- | --- | --- | --- | --- |
| `firefox` | Firefox | `firefox` (pacman) | Firefox | `/usr/lib/firefox/distribution/` |
| `zen` | Zen | `zen-browser-bin` (AUR) | Firefox | Zen's install dir `distribution/` |
| `librewolf` | LibreWolf | `librewolf-bin` (AUR) | Firefox | `/usr/lib/librewolf/distribution/` |
| `chromium` | Chromium | `chromium` (pacman) | Chromium | `/etc/chromium/policies/managed/` |
| `chrome` | Google Chrome | `google-chrome` (AUR) | Chromium | `/etc/opt/chrome/policies/managed/` |
| `brave` | Brave | `brave-bin` (AUR) | Chromium | `/etc/brave/policies/managed/` |
| `none` | skip | — | — | — |

3. Save the choice to `local.toml`, set it as default (`xdg-settings set default-web-browser <desktop-file>`), and export `BROWSER` in `~/.config/hypr/local/env.conf`. `dot browser set <id>` changes it later and re-runs this stage.

**Extensions through policy, not by hand.** The installer writes one policy file per family from a tracked list `browser/extensions.toml` (system paths, so written with `sudo install`, not Stow):

- Chromium family: `dotfiles.json` with `ExtensionInstallForcelist` containing Vimium (`dbepggeogbaibhgnhhndojpepiihcmeb`; verify on the Chrome Web Store).
- Firefox family: `policies.json` with `ExtensionSettings` → Vimium (`vimium-ff` on addons.mozilla.org, `installation_mode = "force_installed"`, `install_url` = the AMO latest-xpi URL).
- The list is extensible: each entry has a Chromium id and/or an AMO slug, so more extensions (e.g. uBlock Origin) are one line each.

**Vimium theme.** Vimium keeps its settings in extension storage, including a "CSS for Vimium UI" field, and does not read files from disk.

- Template `vimium.css.tpl` styles link hints, the HUD and the Vomnibar from the palette. Tracked `stow/browser/vimium-options.json` holds keymaps and settings, with the CSS field filled at render time into `theme/current/vimium-options.json`.
- First, verify whether Vimium reads managed storage (`chrome.storage.managed` / Firefox `3rdparty` policy). If it does, push the rendered options through the same policy file and re-write it on every theme switch.
- If it does not, `dot theme set` copies the rendered CSS to the clipboard and sends one notification: "Vimium: paste into Options → CSS for Vimium UI". `dot browser vimium` re-imports on demand. Document this one manual step in the README.

**Browser UI colors.**

- Chromium family: set `BrowserThemeColor` (verify policy name per browser) to the theme's `background` in the same managed policy file; reload hook rewrites it, and the change applies on browser restart.
- Firefox family: write `user.js` (enables `toolkit.legacyUserProfileCustomizations.stylesheets`) and a `chrome/userChrome.css` that includes `theme/current/firefox.css` (tabs, toolbar, URL bar colors), into the default profile found from `profiles.ini`. Zen: verify whether its own theming (mods) is the better hook.
- All browsers follow `prefer-dark` / `prefer-light` for web content via the GTK color-scheme setting already set by the theme engine.

**Qt.** Install `qt6ct` (and `qt5ct` if any Qt5 app is in the package list), set `QT_QPA_PLATFORMTHEME=qt6ct`, render `qt6ct.colors` from the palette and point `qt6ct.conf` at it. Kvantum is out of scope unless a Qt app looks wrong with qt6ct.

## Hardware profiles

Hardware differences live only in `~/.config/hypr/local/*.conf` (written once, then owned by the user) and optional tracked `hosts/<hostname>.conf`; the shared config never branches on hardware.

| Profile | Detected by | What the installer adds |
| --- | --- | --- |
| Laptop | `/sys/class/power_supply/BAT*` exists | `laptop.txt` packages; `local/input.conf` with touchpad natural scroll, tap-to-click, 3-finger workspace swipe; brightness keys via `brightnessctl`; `hypridle` dim at 2.5 min, lock at 5 min, suspend at 15 min on battery; battery module enabled in Wayle; lid close suspends via logind defaults |
| Desktop | no battery | `hypridle` lock at 10 min, display off at 15 min, no suspend |
| Nvidia | a PCI display controller with vendor `0x10de` | driver package by GPU generation from the PCI device id (implemented: `nvidia_packages` in `lib/detect.sh`): since driver 590 (Dec 2025) the repo packages are open kernel modules for Turing (device id ≥ `0x1e00`) and newer (`nvidia-open`, `nvidia-open-lts`, or `nvidia-open-dkms` + headers for other kernels), Maxwell to Volta (≥ `0x1340`) need `nvidia-580xx-dkms` from the AUR, Kepler and older get no driver; an installed driver is always kept; install config `nvidia_driver` overrides; `local/env.conf` with `LIBVA_DRIVER_NAME,nvidia`, `__GLX_VENDOR_LIBRARY_NAME,nvidia`, `NVD_BACKEND,direct`; ensure `nvidia_drm.modeset=1` (default on current drivers, check `/sys/module/nvidia_drm/parameters/modeset`) |
| Hybrid laptop (Intel/AMD + Nvidia) | both an iGPU and Nvidia present | same as Nvidia, but run Hyprland on the iGPU (`AQ_DRM_DEVICES` order) and leave Nvidia for offload; flag for manual review |
| Multiple monitors | more than one entry in `hyprctl monitors -j` | `local/monitors.conf` with one `monitor =` line per output at preferred mode and auto position, plus workspace-to-monitor rules (1–5 on primary, 6–10 on secondary); recommend `nwg-displays` for interactive editing |

**Implemented (phase 6):** laptop/desktop variants are tracked side by side and linked by stage 50 (`~/.config/hypr/idle.conf` → `idle-laptop.conf`/`idle-desktop.conf`, sourced by `hypridle.conf`; `~/.config/wayle/layout.toml` → `layout-laptop.toml`/`layout-desktop.toml`, imported by Wayle's `config.toml`, because Wayle cannot hide its battery module). Stage `65-hardware` writes `local/env.lua` once for NVIDIA (Lua, since the Hyprland config is Lua only) and reports `nvidia_drm.modeset`. `bin/dot-monitors` runs from autostart and writes `local/monitors.lua` once when 2+ monitors are connected. Stage `45-migrate` runs `migrations/NNNN-*.sh` once per machine; the first run on a machine records existing migrations without running them. `dot doctor` is `lib/doctor.sh`.

**Package side, implemented in phase 1:** stage 10 detects the CPU vendor (`/proc/cpuinfo`), every display controller's PCI vendor (Intel `0x8086`, AMD `0x1002`, NVIDIA `0x10de`) and a battery; stage 20 then adds the matching `packages/hardware/*.txt` lists. `"hardware": false` in the config turns this off. Phase 6 adds the configuration side (env, input, monitors) and the NVIDIA driver choice.

On a fresh install no Hyprland session exists yet, so monitor detection runs on first login through a one-shot `exec-once` that writes `monitors.conf` only if it does not exist, then reloads.

## Commands and keybinds

All user actions go through one `dot` CLI so keybinds, menus and docs call the same code paths.

| Command | Does |
| --- | --- |
| `dot install [flags]` | runs `install.sh` |
| `dot update` | `git pull --rebase` in `$DOTFILES_DIR`, then `dot install --yes`; refuses if the working tree is dirty and says so |
| `dot theme list` | theme ids grouped by family, current one marked |
| `dot theme set <id>` | `dot-theme-set <id>` |
| `dot theme next` / `prev` | cycles within the catalog order |
| `dot theme current` | prints the active id |
| `dot theme new <id> [--from-ghostty <name>]` | scaffolds `themes/<id>/colors.toml` |
| `dot restow` | stage `50-stow` only |
| `dot doctor` | checks: broken symlinks into the repo, `ghostty +validate-config`, `hyprctl configerrors` empty, rendered theme present for every template, required services active, `nvim --headless +qa` exits 0 |
| `dot edit <app>` | opens that app's stow folder in `$EDITOR` |

| Keybind | Action |
| --- | --- |
| `SUPER+RETURN` | Ghostty |
| `SUPER+SPACE` | Walker launcher |
| `SUPER+CTRL+SHIFT+SPACE` | theme picker (`dot-theme-picker`, Walker dmenu) |
| `SUPER+SHIFT+T` | next theme |
| `SUPER+V` | clipboard history (cliphist via Walker) |
| `SUPER+ESCAPE` | power menu (lock, suspend, reboot, shutdown) |
| `SUPER+Q` | close window |
| `SUPER+1..0` / `SUPER+SHIFT+1..0` | go to / move to workspace |
| `PRINT` / `SHIFT+PRINT` | screenshot region / full output (grim + slurp) to clipboard and `~/Pictures/Screenshots` |
| media, volume, brightness keys | `playerctl`, `wpctl`, `brightnessctl` (Wayle shows the OSD) |

`SUPER+K` opens a Walker list of all binds, generated from `hyprctl binds -j`, so the cheat sheet never drifts from the config.

## Implementation phases

Build in six phases, each ending in a commit and a passing check, so the owner can test on real hardware between phases.

1. **Skeleton and installer core.** Repo layout, `lib/common.sh`, `lib/detect.sh`, stages 00–30 and 50, `dot` CLI with `install`, `update`, `restow`.
   - Accept when: `shellcheck` passes on every script; `install.sh --dry-run` on an existing system lists actions and changes nothing; a second real run reports no changes.
2. **Session and core apps.** Hyprland, hypridle, hyprlock, Ghostty, zsh + Oh My Zsh + p10k, Wayle, Walker, git, with hard-coded Tokyo Night colors.
   - Accept when: login lands in a working Hyprland session with bar, launcher, terminal and prompt; `hyprctl configerrors` is empty; `ghostty +validate-config` passes.
3. **Theme engine.** `dot-theme-render`, `dot-theme-set`, templates for every app in the Per-application table, reload hooks, `tokyonight-night` as the first palette; replace the hard-coded colors from phase 2.
   - Accept when: switching between two themes changes Hyprland borders, Ghostty, Wayle, Walker and an open Neovim without restarting anything except where the table says restart; no tracked file changes (`git status` clean); renderer has unit tests for every template modifier and fails loudly on an unknown key.
4. **Theme catalog.** All palettes from the Theme catalog, the Ghostty import helper, wallpapers, the theme picker.
   - Accept when: `dot theme set` succeeds for every id; each palette cites its upstream source in a comment at the top of `colors.toml`; contrast is at least 4.5:1 for `foreground` and 3:1 for `muted` against `background`.
5. **LazyVim and tooling.** LazyVim starter, theme plugin spec, live reload over sockets, eza/fzf/bat/lazygit/btop configs.
   - Accept when: `nvim --headless "+Lazy! sync" +qa` succeeds; colorscheme follows the active theme on start and on switch.
6. **Hardware, migrations, docs.** Stage 60, laptop/Nvidia/multi-monitor files, migrations runner, `dot doctor`, README with install, update, theme and "add an app" guides.
   - Accept when: `dot doctor` passes on a laptop and a desktop; README steps work on a fresh Arch VM from a clean clone.

7) **Browser and Qt theming.** Stage `25-browser`, policy-installed extensions, Vimium and browser UI templates, Qt colors (see Browser and Qt theming).
   - Accept when: a fresh install prompts once and a re-run does not; Vimium is installed without manual steps in each of the six browsers; a theme switch recolors Vimium (or prints the one documented manual step) and the browser UI after restart.

## Skills for the implementing LLM

Three project skills ship with the repo under `.claude/skills/` and encode the procedures that recur during implementation; load the matching one before each kind of task.

| Skill | Load it when | What it enforces |
| --- | --- | --- |
| `dotfiles-add-theme` | adding or fixing a palette in `themes/` | upstream-sourced values only, full key set, contrast check, render and switch test |
| `dotfiles-add-themed-app` | bringing a new app under the theme system | Stow package + template + fixed include path + reload hook + doctor check + docs row |
| `dotfiles-verify` | before every commit | shellcheck, stow dry-run, Hyprland/Ghostty validation, renderer tests, headless Neovim, idempotent re-run |

Useful external references (read, do not copy wholesale): Omarchy's theming docs and `bin/omarchy-theme-set*` scripts in `basecamp/omarchy` for the staging, overlay and hook pattern; the community `omarchy-theming` skill on skills.sh for its `colors.toml` variable conventions; the wayle.app guides for Wayle themes and config; the Hyprland wiki for the installed version.

## Open questions for the owner

These need an answer before or during implementation; the implementer uses the stated default until answered.

- [x] **"Esmerald" theme:** resolved: the esthorace/esmerald VS Code theme, ported as `esmerald` and `esmerald-light` (see Theme catalog).
- [x] **Login method:** decided: keep whatever greeter the Arch install set up (archinstall offers several; the owner's machine uses cosmic-greeter). Never install or switch one unless the config's `greeter` key names one. With none enabled: tty1 login, Hyprland started through `uwsm` from `.zprofile`.
- [x] **Full package list:** provided in `packages/user.txt`, cleaned 2026-11-15: hardware drivers, fonts, greeter, kernel/bootloader and replaced packages moved out.
- [x] **Light themes:** decided: keep Tokyo Night Day, Gruvbox Light and Catppuccin Latte (and Esmerald Light) in v1.
- [x] **Extra themes:** decided: keep Everforest, Kanagawa and Rose Pine for now.
- [ ] **Repo name and location:** de`cided: https://github.com/devanonius/dotfiles (branch main), cloned to ~/dotfiles. bootstrap.sh is implemented: curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash`
- [x] **Browser and Qt theming:** decided: phase 7, with an installer prompt for the browser and Vimium installed and themed (see Browser and Qt theming).
- [x] **Wallpapers:** decided: the owner adds them by hand to `backgrounds/<theme-id>/` at the repo root. Until a folder has images, the theme falls back to a solid background color, and no script may fail on an empty folder.
- [x] **Hyprland config format:** decided: Lua only, Hyprland 0.55 or newer.
- [ ] **keyd files:** the owner supplies the keyd config for `system/keyd/`.

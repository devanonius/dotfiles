# dotfiles

Hyprland rice for Arch Linux, managed with git and GNU Stow: Ghostty, zsh (Oh My Zsh + Powerlevel10k), Wayle, Walker, LazyVim, and one-command global theming in the style of Omarchy.

The full design is in [docs/SPEC.md](docs/SPEC.md). This README covers day-to-day use.

## Status

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Repo skeleton, installer core (preflight, config, detect, pacman, yay, flatpak, stow), `dot` CLI, tests | done |
| 2 | Hyprland (Lua), hypridle, hyprlock, Ghostty, zsh + Oh My Zsh + Powerlevel10k, Wayle, Walker, git; shell and services stages | done, untested on hardware |
| 3 | Theme engine (pywal16): `dot theme`, templates for Hyprland, hyprlock, Ghostty, Wayle, Walker, GTK, btop, prompt | done, tested on hardware |
| 4 | Theme catalog, wallpapers, picker | picker done; catalog next |
| 5 | LazyVim (theme-following, live reload) and CLI tooling (bat, fzf, lazygit, lsd) | done, untested on hardware |
| 6 | Hardware profiles (laptop/desktop, NVIDIA, monitors), migrations, `dot doctor` | done, untested on hardware |
| 7 | Browser (with Vimium) and Qt theming | |

## Install

On an Arch system with network and a sudo user, one line:

```sh
curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash
```

It installs git, clones this repo to `~/dotfiles` (or updates an existing clone), and runs the installer. Options after `bash -s --` go to the installer; a config can be a file or a URL:

```sh
curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash -s -- --dry-run
curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash -s -- -c https://example.com/my.json
```

Or by hand:

```sh
git clone https://github.com/devanonius/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --dry-run   # see what would change
./install.sh             # apply
```

Re-running is always safe: a second run on an up-to-date machine reports "Nothing to do".

| Flag | Effect |
| --- | --- |
| `-c FILE`, `--config FILE` | JSON config: which modules to install, plus extra packages (see below) |
| `--dry-run` | print every change, make none |
| `--only STAGE` / `--skip STAGE` | run or skip a stage by name (`pacman`, `yay`, `stow`) |
| `--no-packages` | configs only, for machines where you manage packages yourself |
| `--yes` | non-interactive |

After the first run, `dot` is linked into `~/.local/bin`.

## Everyday commands

| Command | Does |
| --- | --- |
| `dot update` | `git pull --rebase`, then re-run the installer; refuses if you have uncommitted changes |
| `dot restow` | re-link configs only |
| `dot fonts` | pick Nerd Fonts again and install them |
| `dot packages list [-c FILE]` | packages that apply to this machine and config |
| `dot packages check [-c FILE]` | verify every package name exists (run after editing `packages/` or a config) |
| `dot doctor` | check links, rendered theme, Ghostty/Hyprland/Neovim configs, services, NVIDIA setup; read-only |
| `dot theme …` | see [Themes](#themes) |
| `dot-monitors [--force]` | write `~/.config/hypr/local/monitors.lua` from the connected monitors (runs once by itself on first login with 2+ monitors) |

## Desktop

Hyprland is configured in Lua (Hyprland 0.55 or newer), one file per topic in `stow/hypr/.config/hypr/`: `defaults.lua` (your preferred apps), `binds.lua`, `monitor.lua`, `input.lua`, `layout.lua`, `animations.lua`, `rules.lua`, `env.lua`, `autostart.lua`, `theme.lua`. Per-machine settings go in `~/.config/hypr/local/` (not in the repo): `monitors.lua`, `input.lua` (keyboard layout), `env.lua`, `binds.lua`, `overrides.lua`, each loaded only if it exists. Example:

```lua
-- ~/.config/hypr/local/input.lua
hl.config({ input = { kb_layout = "se" } })
```

| Key | Action |
| --- | --- |
| `SUPER+RETURN` | terminal (Ghostty) |
| `SUPER+SPACE` | launcher (Walker) |
| `SUPER+E` | file manager |
| `SUPER+V` | clipboard history |
| `SUPER+ESCAPE` | power menu |
| `SUPER+CTRL+L` | lock |
| `SUPER+Q` / `F` / `T` | close / fullscreen / toggle floating |
| `SUPER+arrows`, `SUPER+SHIFT+arrows` | focus / move window |
| `SUPER+1..0`, `SUPER+SHIFT+1..0` | go to / move to workspace |
| `SUPER+S`, `SUPER+SHIFT+S` | scratchpad / move to scratchpad |
| `PRINT`, `SHIFT+PRINT` | screenshot region / screen (clipboard + `~/Pictures/Screenshots`) |

The login screen archinstall set up is kept. Without one, log in on tty1 and Hyprland starts from `~/.zprofile` through uwsm.

## How configs are deployed

Each folder in `stow/` mirrors your home folder and is linked file by file (`stow --no-folding --dotfiles`). A name starting with `dot-` links as `.`: `stow/zsh/dot-zshrc` becomes `~/.zshrc`. Use that for files in your home folder itself; folders like `.config` keep their real names. Editing `~/.config/<app>/...` edits the repo file, so `git diff` shows it straight away; commit and push from here. Files that were in the way are moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never overwritten and never pulled into the repo.

Machine-specific settings go in untracked files (`~/.config/hypr/local/`, `~/.config/zsh/local.zsh`, `~/.config/git/local`), so one repo serves every machine.

**Laptop or desktop.** Some files exist in both variants in the repo, and the installer links the one for this machine (a battery means laptop): `~/.config/wayle/layout.toml` (desktops get no battery module) and `~/.config/hypr/idle.conf` (laptop: dim 2.5 min, lock 5, screen off 5.5, suspend 15; desktop: lock 10, screens off 15, no suspend).

**Hardware files.** Stage `65-hardware` writes `~/.config/hypr/local/env.lua` once on NVIDIA machines (VA-API and GLX variables; hybrid laptops get a commented GPU-selection file instead). With two or more monitors, `dot-monitors` writes `local/monitors.lua` on first login: each output at its preferred mode left to right, workspaces 1–5 on the leftmost and 6–10 on the next. Both files are yours afterwards; the installer never overwrites them.

**Migrations.** One-time fixes for machines installed from an older version live in `migrations/` and run once per machine (stage `45-migrate`); see `migrations/README.md`.

## Config file

`install.sh -c my.json` (or `dot install -c my.json`) chooses what gets installed. Three files are merged, later ones winning; objects merge, lists replace:

1. `config/default.json`: the repo default, always used
2. `~/.config/dotfiles/config.json`: this machine's settings, untracked, used automatically when present (so `dot update` keeps using it)
3. the file given with `-c`

```json
{
  "$schema": "./config.schema.json",
  "modules": { "user": false },
  "hardware": true,
  "fonts": ["ttf-firacode-nerd", "ttf-iosevka-nerd"],
  "extra_packages": {
    "pacman":  ["firefox", "obsidian"],
    "aur":     ["visual-studio-code-bin"],
    "flatpak": ["com.spotify.Client"]
  },
  "flatpak": { "scope": "user" }
}
```

- **modules**: each key is a file `packages/<key>.txt`, `true` or `false`. `base` and `aur` always install. Add a module by adding a `packages/<name>.txt`.
- **hardware** (default `true`): installs the `packages/hardware/` lists that match the detected CPU (Intel/AMD microcode), GPUs (Intel, AMD, NVIDIA) and battery, and writes the hardware files (see [How configs are deployed](#how-configs-are-deployed)).
- **nvidia_driver** (default `"auto"`): `auto` picks by GPU generation: the open kernel modules from the repos for Turing (RTX 20, GTX 16) and newer (`nvidia-open` for the stock kernel, `nvidia-open-lts`, or `nvidia-open-dkms` with headers for other kernels), `nvidia-580xx-dkms` from the AUR for Maxwell, Pascal and Volta, nothing for Kepler and older. A driver that is already installed is always kept. `"open"` or `"580xx"` forces a family; `"none"` installs no driver.
- **fonts**: Nerd Fonts from `packages/fonts/nerd-fonts.txt`. `"ask"` (default) shows a pick-list once and remembers the choice; `dot fonts` asks again. Or `"all"`, `"none"`, or a list. JetBrains Mono Nerd Font is always installed (the terminal uses it).
- **extra_packages**: packages on top of the modules. Flatpak is only installed when the flatpak list is non-empty. `scope: "user"` needs no root; `"system"` installs for everyone.
- Mistakes fail fast with every problem listed: unknown keys, wrong types, unknown modules or fonts, invalid package names. `config/config.schema.json` gives editors completion and validation.

## Testing

`tests/run.sh` tests the installer for real on Arch (WSL, a VM, CI); it installs packages, so use a throwaway system. `tests/run.sh --static` only runs the checks that change nothing. `tests/docker.sh` runs everything in a fresh `archlinux` container (needs Docker; on Windows run it from WSL or Git Bash). Both use the small `tests/ci.json` config unless you pass another one.

## Themes

```sh
dot theme list            # * marks the active theme
dot theme set gruvbox-dark
dot theme next            # also SUPER+SHIFT+T
```

A theme is `themes/<id>/colors.json` (a pywal colorscheme) plus `theme.json` (name, dark/light, Neovim scheme, upstream source); see `themes/README.md`. `dot theme set` runs pywal16, which renders `~/.config/wal/templates/*` (tracked in `stow/wal/`) into `~/.cache/wal/` and recolors open terminals. Then it reloads Hyprland and Ghostty, sets GTK to dark or light, writes Wayle's palette with `wayle config set` (kept in `~/.config/wayle/runtime.toml`), switches every open Neovim through its server socket, and shows a notification. Walker reloads its CSS by itself. `SUPER+CTRL+SHIFT+SPACE` opens a picker. Terminal tools (bat, fzf, lazygit, lsd, the prompt) use the 16 ANSI colors, so they follow Ghostty's palette with no per-theme files. Neovim's lazy-lock.json is written into the repo (`stow/nvim/.config/nvim/`): commit it to pin plugin versions on every machine. Nothing else tracked changes when you switch.

To theme another app, add a template to `stow/wal/.config/wal/templates/` and point the app at `~/.cache/wal/<file>` (skill: `dotfiles-add-themed-app`). Your own scripts in `~/.config/dotfiles/hooks/theme-set.d/` run after every switch with the theme id as `$1`.

## System files (keyd)

`system/<module>/` mirrors the root of the filesystem and is **copied** with sudo (not linked), because services read these files at boot. `system/keyd/etc/keyd/default.conf` becomes `/etc/keyd/default.conf`. Edit the repo copy, then run `dot install --only system`: changed files are backed up to `~/.local/state/dotfiles/backup/`, installed, and the units in `system/<module>.service` are enabled and restarted. A module's system files are installed only when the module is on (`"modules": { "keyd": true }`, the default).

## Packages

| Path | Installed when |
| --- | --- |
| `packages/base.txt`, `packages/aur.txt` | always (`aur.txt` through yay) |
| `packages/<module>.txt` (`desktop`, `user`, ...) | the module is `true` in the config |
| `packages/hardware/*.txt` | the matching hardware is detected and `hardware` is `true` |
| `packages/fonts/nerd-fonts.txt` | the font picker / `fonts` setting |
| `packages/exclude.txt` | never: packages this rice replaces (dunst, wofi, polkit-kde-agent, iwd, eza) are dropped from every module and hardware list |

One name per line, `#` comments. Removing a line does not uninstall anything. `tools/generate-user-list.sh` rebuilds `user.txt` from what is installed on this machine, leaving out everything the other lists already cover, the replaced packages, and kernel/bootloader packages; it also lists AUR packages missing from `aur.txt`.

## Wallpapers

Put images in `backgrounds/<theme-id>/` (for example `backgrounds/tokyonight-night/`). A theme without images falls back to a plain background in its main color.

## Working on this repo from Windows

`.gitattributes` forces LF line endings. Git on Windows does not record the executable bit, so mark the two entry points once before your first commit:

```sh
git add --chmod=+x install.sh bin/dot
```

`dot` and `bash install.sh` work regardless.

## For the implementing LLM

Read `docs/SPEC.md`, then load the matching skill before each task: `dotfiles-add-theme`, `dotfiles-add-themed-app`, and `dotfiles-verify` before every commit.

The skills live in `skills/`. For Claude Code to pick them up automatically, copy them once into `.claude/skills/` (and commit that folder):

```sh
mkdir -p .claude && cp -r skills .claude/skills
```

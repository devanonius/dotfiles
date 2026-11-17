# dotfiles

Hyprland rice for Arch Linux, managed with git and GNU Stow: Ghostty, zsh (Oh My Zsh + Powerlevel10k), Wayle, Walker, LazyVim, and one-command global theming in the style of Omarchy.

The full design is in [docs/SPEC.md](docs/SPEC.md). This README covers day-to-day use.

## Status

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Repo skeleton, installer core (preflight, config, detect, pacman, yay, flatpak, stow), `dot` CLI, tests | done |
| 2 | Hyprland (Lua), hypridle, hyprlock, Ghostty, zsh + Oh My Zsh + Powerlevel10k, Wayle, Walker, git; shell and services stages | done, untested on hardware |
| 3 | Theme engine (pywal16): `dot theme`, templates for Hyprland, hyprlock, Ghostty, Wayle, Walker, GTK, btop, prompt | done, tested on hardware |
| 4 | Theme catalog (19 themes), per-theme wallpapers, picker, Ghostty import tool | done, untested on hardware |
| 5 | LazyVim (theme-following, live reload) and CLI tooling (bat, fzf, lazygit, lsd) | done, untested on hardware |
| 6 | Hardware profiles (laptop/desktop, NVIDIA, monitors), migrations, `dot doctor` | done, untested on hardware |
| 7 | Browser (with Vimium) and Qt theming | done, untested on hardware |

## Install

On an Arch system with network and a sudo user, one line:

```sh
curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash
```

It installs git, clones this repo to `~/dotfiles` (or updates an existing clone), and runs the installer. On the first run without a config it asks a few questions on the terminal (which package groups, which browser, which Nerd Fonts) and saves the answers to `~/.config/dotfiles/config.json`, so later runs and `dot update` don't ask again; delete that file to be asked again. Options after `bash -s --` go to the installer; a config can be a file or a URL:

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
| `dot edit [<app>]` | open an app's config folder in the repo in your editor (no app: list them) |
| `dot-keybinds [--print]` | the keybind cheat sheet (also `SUPER+K`) |
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
| `SUPER+K` | all keybinds with descriptions (read live from Hyprland) |
| `SUPER+Q` / `F` / `T` | close / fullscreen / toggle floating |
| `SUPER+arrows`, `SUPER+SHIFT+arrows` | focus / move window |
| `SUPER+1..0`, `SUPER+SHIFT+1..0` | go to / move to workspace |
| `SUPER+S`, `SUPER+SHIFT+S` | scratchpad / move to scratchpad |
| `PRINT`, `SHIFT+PRINT` | screenshot region / screen (clipboard + `~/Pictures/Screenshots`) |

The login screen archinstall set up is kept. Without one, log in on tty1 and Hyprland starts from `~/.zprofile` through uwsm.

## Browser

The installer asks once which browser to use (install config `"browser"`: `"ask"`, an id, or `"none"`): Firefox, Zen, LibreWolf, Chromium, Google Chrome or Brave. It installs it (AUR browsers as prebuilt `-bin` packages where they exist), makes it the default, and installs the extensions in `browser/extensions.json` (Vimium) through the browser's enterprise policy, so nothing is clicked by hand. `dot browser set <id>` switches later; `dot browser list` shows the ids.

Colors:

- **Chromium, Chrome, Brave:** the toolbar takes the theme's background color through the `BrowserThemeColor` policy, rewritten on every theme switch (applied at once on Chrome/Chromium 142+, otherwise on the next start).
- **Firefox, LibreWolf:** the default "System theme — auto" follows GTK, which the theme engine colors; restart the browser after switching. Zen uses its own theming and is not colored.
- Web pages follow the theme's dark/light setting.
- **Vimium** keeps its look in its own settings (it does not read files or policies). After switching themes, run `dot browser vimium`, then in Vimium's options paste into "CSS for Vimium UI" and Save. This is the one manual step.

## Passwords and git credentials

KeePassXC is the password manager and the system's Secret Service (the
D-Bus password store apps use). git saves HTTPS usernames and passwords or
personal access tokens there through `git-credential-libsecret`, one entry
per repository URL (`credential.useHttpPath`), so different repos can use
different accounts and tokens. Everything stays in your KeePassXC database.

One-time setup in KeePassXC (it starts in the tray at login):

1. Create or open your database.
2. Database > Database Settings > Secret Service Integration: choose the group
   that apps may use (e.g. a new group "Secret Service").
3. Tools > Settings > Secret Service Integration is already switched on by
   the installer; leave it on.

The first `git push` or `git pull` over HTTPS to a repo asks for the username
and password/token once and stores it in that group; later runs ask KeePassXC
(which may ask you to unlock the database). To change a token, edit or delete
the entry in KeePassXC. SSH remotes use your SSH key instead. `dot doctor`
warns if another Secret Service (GNOME Keyring, KWallet) has taken over.

## How configs are deployed

Each folder in `stow/` mirrors your home folder and is linked file by file (`stow --no-folding --dotfiles`). A name starting with `dot-` links as `.`: `stow/zsh/dot-zshrc` becomes `~/.zshrc`. Use that for files in your home folder itself; folders like `.config` keep their real names. Editing `~/.config/<app>/...` edits the repo file, so `git diff` shows it straight away; commit and push from here. Files that were in the way are moved to `~/.local/state/dotfiles/backup/<timestamp>/`, never overwritten and never pulled into the repo.

Machine-specific settings go in untracked files (`~/.config/hypr/local/`, `~/.config/zsh/local.zsh`, `~/.config/git/local`), so one repo serves every machine.

**Laptop or desktop.** Some files exist in both variants in the repo, and the installer links the one for this machine (a battery means laptop): `~/.config/wayle/layout.toml` (desktops get no battery module) and `~/.config/hypr/idle.conf` (laptop: dim 2.5 min, lock 5, screen off 5.5, suspend 15; desktop: lock 10, screens off 15, no suspend).

**Qt apps** (KeePassXC and others) use qt6ct with the Fusion style and a color scheme rendered from the theme (`~/.config/qt6ct/colors/dotfiles.conf`); they pick up a new theme when restarted.

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

## Adding an app

Say the app is `foo`:

1. **Package.** Add `foo` to the module that fits (`packages/desktop.txt` for the desktop, `packages/user.txt` for personal apps), or to `packages/aur.txt`, preferring a `-bin` package so nothing compiles. Check the name with `dot packages check`.
2. **Config.** Put its files in `stow/foo/`, mirroring your home folder: `stow/foo/.config/foo/config`. Files directly in your home folder use a `dot-` prefix (`stow/foo/dot-foorc` becomes `~/.foorc`). Run `dot restow`. From then on `dot edit foo` opens the folder, and edits are live through the links.
   - If the app rewrites its own config file (like btop, KeePassXC, qt6ct), don't track the file; seed it once in `lib/install/52-apps.sh` instead.
3. **Colors.** Add a template `stow/wal/.config/wal/templates/foo-colors` (the file name is what lands in `~/.cache/wal/`). It uses pywal's variables: the roles `{background}`, `{foreground}`, `{surface}`, `{elevated}`, `{border}`, `{muted}`, `{accent}`, `{accent2}`, `{selection}` (meanings in `themes/README.md`) and `{color0}`–`{color15}` for terminal colors; `.strip` drops the `#`. It is Python `str.format`, so a literal `{` or `}` is written `{{` or `}}`.
   - Best: the app's config includes `~/.cache/wal/foo-colors` (most apps have an include or import option).
   - If it can't include a file, link it from the place the app reads: add a `link_generated` line to `theme_links` in `lib/theme.sh`.
   - If the app only takes colors from the terminal, configure it with ANSI color numbers (like bat, fzf, lazygit); nothing else is needed.
4. **Reload.** If the running app can reload (a signal or a command), add it to `theme_reload` in `lib/theme.sh` as `hook <command> &` (`hook` caps it at 2 s and ignores failures; `&` lets it run alongside the others).
5. **Start and keys.** Start it at login in `stow/hypr/.config/hypr/autostart.lua`, or as a systemd user service listed in `lib/install/70-services.sh`. A keybind goes in `binds.lua` with a description, so it shows up under `SUPER+K`.
6. **Check.** `tests/run.sh --static` renders every template with every theme and fails on a typo; then `dot theme next` should recolor the app, and `dot doctor` should stay green.

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


| Family | Themes |
| --- | --- |
| Tokyo Night | `tokyonight-night` (default), `tokyonight-storm`, `tokyonight-moon`, `tokyonight-day` (light) |
| Catppuccin | `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte` (light) |
| Gruvbox | `gruvbox-dark`, `gruvbox-light` (light) |
| Esmerald | `esmerald`, `esmerald-night`, `esmerald-light` (light) |
| Others | `habamax`, `onedark`, `darcula`, `everforest-dark`, `kanagawa-wave`, `rose-pine` |

`SUPER+CTRL+SHIFT+SPACE` opens the picker, `SUPER+SHIFT+T` goes to the next theme. Wallpapers come from `backgrounds/<theme id>/` (you add them): the first one is shown when the theme is applied, `dot background next` (`SUPER+CTRL+SPACE`) steps through the rest, and a theme without wallpapers gets a plain screen in its background color.
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

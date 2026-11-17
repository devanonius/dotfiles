# shellcheck shell=bash
# Theme switching on top of pywal16 (`wal`). Sourced by bin/dot and the
# 80-theme install stage. Themes live in themes/<id>/ (see themes/README.md).
#
# `dot theme set <id>`:
#   1. wal applies themes/<id>/colors.json: renders the templates from
#      ~/.config/wal/templates into ~/.cache/wal/ and recolors open terminals
#   2. links the few apps that cannot include a file from ~/.cache/wal
#   3. sets GTK's dark/light preference from the theme's variant
#   4. tells running apps to reload (each hook: 2 s timeout, never fatal)
#   5. runs ~/.config/dotfiles/hooks/theme-set.d/* with the theme id as $1
#      (also the Chromium-family browser toolbar color, through its policy)
#   6. shows the theme's wallpaper (backgrounds/<id>/) or its background color
#   7. shows a notification with the new theme's name

THEMES_DIR="$DOTFILES_DIR/themes"
THEME_STATE="$DOTFILES_STATE/theme"
BACKGROUNDS_DIR="$DOTFILES_DIR/backgrounds"
WAL_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wal"
DEFAULT_THEME=tokyonight-night

theme_ids() {
  local dir
  for dir in "$THEMES_DIR"/*/; do
    [[ -f $dir/colors.json && -f $dir/theme.json ]] && basename "$dir"
  done
  return 0
}

theme_exists()  { [[ -f $THEMES_DIR/$1/colors.json && -f $THEMES_DIR/$1/theme.json ]]; }
theme_meta()    { jq -r --arg k "$2" '.[$k] // empty' "$THEMES_DIR/$1/theme.json"; }
theme_current() { [[ -f $THEME_STATE/name ]] && cat "$THEME_STATE/name"; return 0; }

theme_list() {
  local id current name
  current=$(theme_current)
  while read -r id; do
    name=$(theme_meta "$id" name)
    if [[ $id == "$current" ]]; then
      printf '%s* %-24s%s %s (%s)\n' "$C_GREEN" "$id" "$C_RESET" "$name" "$(theme_meta "$id" variant)"
    else
      printf '  %-24s %s (%s)\n' "$id" "$name" "$(theme_meta "$id" variant)"
    fi
  done < <(theme_ids)
}

# theme_step +1|-1 : the id after/before the current one, wrapping around.
theme_step() {
  local ids=() current i
  mapfile -t ids < <(theme_ids)
  (( ${#ids[@]} )) || die "no themes in $THEMES_DIR"
  current=$(theme_current)
  for i in "${!ids[@]}"; do
    if [[ ${ids[$i]} == "$current" ]]; then
      printf '%s\n' "${ids[$(( (i + $1 + ${#ids[@]}) % ${#ids[@]} ))]}"
      return 0
    fi
  done
  printf '%s\n' "${ids[0]}"
}

# link_generated TARGET SOURCE : point an app's file at a pywal output.
# A real file in the way is moved aside once (never overwritten).
link_generated() {
  local target=$1 source=$2
  [[ -L $target && $(readlink "$target") == "$source" ]] && return 0
  mkdir -p "$(dirname "$target")"
  if [[ -e $target && ! -L $target ]]; then
    mv "$target" "$target.before-dotfiles"
    warn "moved existing $(pretty "$target") to $(pretty "$target").before-dotfiles"
  fi
  ln -sfn "$source" "$target"
}

theme_links() {
  local cfg=${XDG_CONFIG_HOME:-$HOME/.config}
  link_generated "$cfg/gtk-3.0/gtk.css" "$WAL_CACHE/gtk.css"
  link_generated "$cfg/gtk-4.0/gtk.css" "$WAL_CACHE/gtk.css"
  link_generated "$cfg/walker/themes/dotfiles/style.css" "$WAL_CACHE/walker.css"
  link_generated "$cfg/btop/themes/dotfiles.theme" "$WAL_CACHE/btop.theme"
  # Qt apps (KeePassXC, ...) through qt6ct; read when a Qt app starts.
  link_generated "$cfg/qt6ct/colors/dotfiles.conf" "$WAL_CACHE/qt6ct-colors.conf"
  # btop rewrites btop.conf itself, so it is not tracked; only make sure it
  # uses the generated theme.
  local btop="$cfg/btop/btop.conf"
  if [[ ! -f $btop ]]; then
    printf 'color_theme = "dotfiles"\ntheme_background = False\n' > "$btop"
  elif ! grep -q '^color_theme = "dotfiles"' "$btop"; then
    sed -i 's/^color_theme = .*/color_theme = "dotfiles"/' "$btop"
    grep -q '^color_theme' "$btop" || printf 'color_theme = "dotfiles"\n' >> "$btop"
  fi
}

# Run one reload hook: quietly, at most 2 seconds, never fatal.
hook() { timeout 2 "$@" >/dev/null 2>&1 || true; }

# Tell every running app to reload. They are independent, so they all start
# at once (each still capped by hook's timeout); theme_set waits for them.
theme_reload() {
  local variant=$1 scheme=prefer-dark gtk=adw-gtk3-dark
  [[ $variant == light ]] && { scheme=prefer-light; gtk=adw-gtk3; }
  if has_cmd gsettings; then
    hook gsettings set org.gnome.desktop.interface color-scheme "$scheme" &
    hook gsettings set org.gnome.desktop.interface gtk-theme "$gtk" &
  fi
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && has_cmd hyprctl && { hook hyprctl reload & }
  hook pkill -USR2 -x ghostty &
  theme_wayle &
  theme_nvim_reload &
  # Browser toolbar color (Chromium family); see lib/browser.sh.
  # shellcheck source=lib/browser.sh
  source "$DOTFILES_DIR/lib/browser.sh"
  browser_theme_apply &
  # Walker reloads style.css itself.
  return 0
}

# Every running Neovim listens on $XDG_RUNTIME_DIR/nvim.<pid>.0; ask each to
# re-read the theme (lua/dotfiles/theme.lua in the nvim config).
theme_nvim_reload() {
  local sock
  has_cmd nvim || return 0
  for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*; do
    [[ -S $sock ]] || continue
    hook nvim --server "$sock" --remote-expr 'luaeval("require(\"dotfiles.theme\").reload()")' &
  done
  wait
}

# Wayle: write the palette through its CLI, which applies it live and keeps
# it in ~/.config/wayle/runtime.toml for the next start.
theme_wayle() {
  has_cmd wayle && [[ -f $WAL_CACHE/wayle-palette ]] || return 0
  # One call with the whole palette as a TOML table: every `wayle config set`
  # loads the config and saves runtime.toml, and each save restyles the bar,
  # so one call instead of ten keys means one restyle. 5 s: it loads the
  # whole config first.
  timeout 5 wayle config set styling.palette "$(<"$WAL_CACHE/wayle-palette")" >/dev/null 2>&1 || true
}

# Neovim reads the theme's plugin and colorscheme from this file
# (stow/nvim/.config/nvim/lua/plugins/theme.lua). JSON strings are valid Lua.
theme_nvim() {
  jq -r '"return { plugin = \(.nvim_plugin // "" | tojson), scheme = \(.nvim_scheme | tojson), background = \(.variant | tojson) }"' \
    "$THEMES_DIR/$1/theme.json" > "$THEME_STATE/nvim.lua"
}

# --- Wallpapers --------------------------------------------------------------
# backgrounds/<theme id>/ holds that theme's wallpapers (added by hand; any
# jpg/png/webp/gif). Wayle draws them (through awww). A theme without any
# gets a plain screen in its background color.

background_files() {
  local dir="$BACKGROUNDS_DIR/$1"
  [[ -d $dir ]] || return 0
  find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort
}

# background_apply <id> [file]: show file (default: the remembered one, or
# the theme's first), or the theme's color when it has no wallpapers.
background_apply() {
  local id=$1 file=${2:-} files=()
  mapfile -t files < <(background_files "$id")
  if (( ${#files[@]} == 0 )); then
    rm -f "$THEME_STATE/background"
    local bg
    bg=$(jq -r '.special.background' "$THEMES_DIR/$id/colors.json")
    has_cmd wayle && hook wayle wallpaper stop
    has_cmd awww && hook awww clear "${bg#\#}"
    return 0
  fi
  if [[ -z $file ]]; then
    file=$(cat "$THEME_STATE/background" 2>/dev/null || true)
    [[ -n $file && -f $file && $file == "$BACKGROUNDS_DIR/$id/"* ]] || file=${files[0]}
  fi
  printf '%s\n' "$file" > "$THEME_STATE/background"
  has_cmd wayle && hook wayle wallpaper set "$file"
  return 0
}

# background_step +1|-1: the next/previous wallpaper of the active theme.
background_step() {
  local id files=() current i n
  id=$(theme_current)
  [[ -n $id ]] || die "no active theme (dot theme set <id> first)"
  mapfile -t files < <(background_files "$id")
  n=${#files[@]}
  (( n )) || { log "$id has no wallpapers (add images to backgrounds/$id/)"; return 0; }
  current=$(cat "$THEME_STATE/background" 2>/dev/null || true)
  for i in "${!files[@]}"; do [[ ${files[$i]} == "$current" ]] && break; done
  [[ ${files[$i]:-} == "$current" ]] || i=-1
  i=$(( (i + $1 + n) % n ))
  background_apply "$id" "${files[$i]}"
  log "wallpaper: ${files[$i]#"$DOTFILES_DIR"/}"
}

# Say which theme is now active, for the keybind and the picker.
theme_notify() {
  [[ -n ${WAYLAND_DISPLAY:-} ]] && has_cmd notify-send || return 0
  hook notify-send -a dotfiles -i preferences-desktop-theme \
    "Theme: $(theme_meta "$1" name)" "$(theme_meta "$1" variant) · dot theme list"
}

theme_user_hooks() {
  local id=$1 script
  for script in "$DOTFILES_CONFIG"/hooks/theme-set.d/*; do
    [[ -x $script ]] || continue
    "$script" "$id" || warn "hook $(pretty "$script") failed"
  done
}

theme_set() {
  local id=$1 variant
  theme_exists "$id" || die "unknown theme '$id' (see: dot theme list)"
  require_cmd wal
  variant=$(theme_meta "$id" variant)

  mkdir -p "$THEME_STATE"
  exec {lock}>"$THEME_STATE/lock"
  flock "$lock"

  # -n: Wayle owns the wallpaper. -q: quiet. -e: skip pywal's own reloads
  # (gtk/xrdb/i3/polybar); this script does the reloading.
  wal -q -n -e --theme "$THEMES_DIR/$id/colors.json" ||
    die "wal failed to apply $id"
  theme_links
  theme_nvim "$id"
  printf '%s\n' "$id" > "$THEME_STATE/name"
  theme_fingerprint "$id" > "$THEME_STATE/fingerprint"
  theme_reload "$variant"
  background_apply "$id" &
  theme_user_hooks "$id"
  wait   # for the reloads started above
  flock -u "$lock"
  theme_notify "$id"
}

# Fingerprint of everything that shapes the rendered theme, so the installer
# re-applies only when the theme or a template changed.
theme_fingerprint() {
  local id=$1
  cat "$THEMES_DIR/$id/colors.json" "$THEMES_DIR/$id/theme.json" \
      "$DOTFILES_DIR"/stow/wal/.config/wal/templates/* 2>/dev/null | md5sum | cut -d' ' -f1
}

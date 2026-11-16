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
#   6. shows a notification with the new theme's name

THEMES_DIR="$DOTFILES_DIR/themes"
THEME_STATE="$DOTFILES_STATE/theme"
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

theme_reload() {
  local variant=$1
  if has_cmd gsettings; then
    if [[ $variant == light ]]; then
      hook gsettings set org.gnome.desktop.interface color-scheme prefer-light
      hook gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3
    else
      hook gsettings set org.gnome.desktop.interface color-scheme prefer-dark
      hook gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
    fi
  fi
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && has_cmd hyprctl && hook hyprctl reload
  hook pkill -USR2 -x ghostty
  theme_wayle
  # Walker reloads style.css itself.
}

# Wayle: write the palette through its CLI, which applies it live and keeps
# it in ~/.config/wayle/runtime.toml for the next start.
theme_wayle() {
  local key value
  has_cmd wayle && [[ -f $WAL_CACHE/wayle-palette ]] || return 0
  while read -r key value; do
    [[ -n $key ]] && hook wayle config set "$key" "$value"
  done < "$WAL_CACHE/wayle-palette"
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
  printf '%s\n' "$id" > "$THEME_STATE/name"
  theme_fingerprint "$id" > "$THEME_STATE/fingerprint"
  theme_reload "$variant"
  theme_user_hooks "$id"
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

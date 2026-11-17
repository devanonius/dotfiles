# shellcheck shell=bash
# Stage 52: first-run settings for apps that rewrite their own config file,
# so the file cannot be a tracked link (btop is handled by the theme stage).
# Each setting is only added when missing; changes made in the app win.

# KeePassXC: be the Secret Service provider (git credentials, see
# stow/git/.config/git/config), live in the tray, and use the Qt palette
# ("classic" theme) so it follows the dotfiles theme through qt6ct.
keepassxc_ini() {
  has_cmd keepassxc || { info "keepassxc not installed; skipped"; return 0; }
  local ini="$HOME/.config/keepassxc/keepassxc.ini"
  if [[ ! -f $ini ]]; then
    changed "write $(pretty "$ini") (Secret Service on, tray icon)"
    (( DRY_RUN )) && return 0
    mkdir -p "$(dirname "$ini")"
    cat > "$ini" <<'INI'
[General]
ConfigVersion=2

[GUI]
ApplicationTheme=classic
MinimizeOnClose=true
ShowTrayIcon=true
MinimizeToTray=true

[FdoSecrets]
Enabled=true
INI
    return 0
  fi
  if grep -q '^\[FdoSecrets\]' "$ini"; then
    info "keepassxc: Secret Service setting present (change it in Tools > Settings)"
  else
    changed "enable KeePassXC Secret Service in $(pretty "$ini")"
    (( DRY_RUN )) && return 0
    printf '\n[FdoSecrets]\nEnabled=true\n' >> "$ini"
  fi
}

# qt6ct: Fusion style with the theme's colors (~/.config/qt6ct/colors/
# dotfiles.conf, linked by the theme engine). Fusion is the Qt style that
# fully follows a custom palette.
qt6ct_conf() {
  local conf="$HOME/.config/qt6ct/qt6ct.conf" scheme="$HOME/.config/qt6ct/colors/dotfiles.conf"
  if [[ ! -f $conf ]]; then
    changed "write $(pretty "$conf") (Fusion style, theme colors)"
    (( DRY_RUN )) && return 0
    mkdir -p "$(dirname "$conf")"
    printf '[Appearance]\ncolor_scheme_path=%s\ncustom_palette=true\nstandard_dialogs=default\nstyle=Fusion\n' "$scheme" > "$conf"
    return 0
  fi
  if grep -q "^color_scheme_path=$scheme$" "$conf" && grep -q '^custom_palette=true$' "$conf"; then
    info "qt6ct: uses the theme colors"
  else
    warn "qt6ct: $(pretty "$conf") does not use the theme colors; in qt6ct pick the \"dotfiles\" color scheme (or delete the file and re-run)"
  fi
}

stage_main() {
  keepassxc_ini
  qt6ct_conf
}

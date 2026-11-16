# shellcheck shell=bash
# Stage 52: first-run settings for apps that rewrite their own config file,
# so the file cannot be a tracked link (btop is handled by the theme stage).
# Each setting is only added when missing; changes made in the app win.

# KeePassXC: be the Secret Service provider (git credentials, see
# stow/git/.config/git/config) and live in the tray.
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
ApplicationTheme=auto
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

stage_main() {
  keepassxc_ini
}

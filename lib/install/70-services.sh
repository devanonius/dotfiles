# shellcheck shell=bash
# Stage 70: enable system and user services, and leave the login screen
# (greeter) alone unless the config asks for one.

SYSTEM_SERVICES=(NetworkManager bluetooth upower power-profiles-daemon)
USER_SERVICES=(hypridle hyprpolkitagent elephant)

# unit_exists [--user] NAME : true if systemd knows the unit file.
unit_exists() {
  local scope=()
  [[ $1 == --user ]] && { scope=(--user); shift; }
  systemctl "${scope[@]}" list-unit-files "$1.service" --no-legend 2>/dev/null | grep -q .
}

enable_system() {
  local svc
  for svc in "${SYSTEM_SERVICES[@]}"; do
    if ! unit_exists "$svc"; then
      info "$svc: not installed, skipped"
    elif systemctl is-enabled --quiet "$svc.service" 2>/dev/null; then
      info "$svc: enabled"
    else
      changed "enable $svc"
      if systemd_running; then
        run sudo systemctl enable --now "$svc.service"
      else
        run sudo systemctl enable "$svc.service"   # starts on next boot
      fi
    fi
  done
}

enable_user() {
  local svc
  # User services need the user's systemd instance (missing under su/sudo).
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "no systemd user session here; user services skipped (re-run from your own login)"
    return 0
  fi
  for svc in "${USER_SERVICES[@]}"; do
    if ! unit_exists --user "$svc"; then
      info "$svc (user): not installed, skipped"
    elif systemctl --user is-enabled --quiet "$svc.service" 2>/dev/null; then
      info "$svc (user): enabled"
    else
      changed "enable user service $svc"
      run systemctl --user enable "$svc.service"
    fi
  done
}

# The display manager archinstall set up (if any), e.g. cosmic-greeter.
current_greeter() {
  local link=/etc/systemd/system/display-manager.service
  [[ -L $link ]] && basename "$(readlink -f "$link")" .service
  return 0
}

greeter() {
  local wanted current
  wanted=$(config_get '.greeter // "keep"')
  current=$(current_greeter)

  if [[ $wanted == keep ]]; then
    if [[ -n $current ]]; then
      info "greeter: keeping $current"
    else
      info "greeter: none; log in on tty1 and Hyprland starts from ~/.zprofile"
    fi
    return 0
  fi

  if [[ -n $current && $current != "$wanted" ]]; then
    warn "greeter: $current is enabled; not switching to $wanted automatically (disable $current first)"
    return 0
  fi
  if [[ $current == "$wanted" ]]; then
    info "greeter: $wanted already enabled"
    return 0
  fi
  if [[ -n $(missing_pkgs "$wanted") ]]; then
    changed "install greeter $wanted"
    local args=(-Syu --needed)
    (( ASSUME_YES )) && args+=(--noconfirm)
    run sudo pacman "${args[@]}" "$wanted"
  fi
  changed "enable greeter $wanted"
  run sudo systemctl enable "$wanted.service"
}

stage_main() {
  if ! has_cmd systemctl; then
    (( DRY_RUN )) && { info "systemctl not available here; skipped"; return 0; }
    die "systemctl not found"
  fi
  enable_system
  enable_user
  greeter
}

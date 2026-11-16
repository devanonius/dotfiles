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

# Other network managers archinstall may have set up. Running one of these
# next to NetworkManager makes them fight over the Wi-Fi card, which shows up
# as "authentication failed" with the right password.
NETWORK_CONFLICTS=(iwd systemd-networkd dhcpcd connman)
NM_DEFER=0   # 1: switch to NetworkManager at the next boot, not now

network_handover() {
  local svc found=()
  for svc in "${NETWORK_CONFLICTS[@]}"; do
    systemctl is-enabled --quiet "$svc.service" 2>/dev/null && found+=("$svc")
  done

  # NetworkManager told to drive Wi-Fi through iwd, which this setup drops.
  local conf
  for conf in /etc/NetworkManager/conf.d/*.conf /etc/NetworkManager/NetworkManager.conf; do
    [[ -f $conf ]] && grep -Eq '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd' "$conf" || continue
    warn "$conf sets wifi.backend=iwd; NetworkManager should use wpa_supplicant"
    if confirm "Set it aside as $conf.bak?"; then
      changed "set aside $conf"
      run sudo mv "$conf" "$conf.bak"
    fi
  done

  (( ${#found[@]} )) || return 0
  warn "also managing the network: ${found[*]} (they conflict with NetworkManager)"
  if confirm "Disable ${found[*]} and use NetworkManager from the next boot?"; then
    changed "disable ${found[*]}"
    # Not --now: the current connection keeps working until the reboot.
    run sudo systemctl disable "${found[@]/%/.service}"
    NM_DEFER=1
    warn "after rebooting, connect to Wi-Fi again in Wayle or with: nmcli --ask device wifi connect <SSID>"
  else
    warn "leaving ${found[*]} enabled; NetworkManager is not enabled to avoid the conflict"
    NM_DEFER=2
  fi
}

enable_system() {
  local svc
  for svc in "${SYSTEM_SERVICES[@]}"; do
    if [[ $svc == NetworkManager ]] && (( NM_DEFER == 2 )); then
      info "NetworkManager: skipped (another network manager is in use)"
    elif ! unit_exists "$svc"; then
      info "$svc: not installed, skipped"
    elif systemctl is-enabled --quiet "$svc.service" 2>/dev/null; then
      info "$svc: enabled"
    else
      changed "enable $svc"
      if systemd_running && ! { [[ $svc == NetworkManager ]] && (( NM_DEFER )); }; then
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
  generate_user_units

  # Inside a running desktop session, start what we enable right away;
  # otherwise the services start with the next login.
  local now=()
  systemctl --user is-active --quiet graphical-session.target 2>/dev/null && now=(--now)

  for svc in "${USER_SERVICES[@]}"; do
    if ! unit_exists --user "$svc"; then
      info "$svc (user): not installed, skipped"
    elif systemctl --user is-enabled --quiet "$svc.service" 2>/dev/null; then
      info "$svc (user): enabled"
    else
      changed "enable user service $svc"
      run systemctl --user enable "${now[@]}" "$svc.service"
    fi
  done
}

# Some programs don't ship a unit file but can write one themselves.
# elephant (Walker's backend) is one: without its service Walker only shows
# "Waiting for elephant...".
generate_user_units() {
  if has_cmd elephant && ! unit_exists --user elephant; then
    changed "generate user service elephant"
    run elephant service enable
    run systemctl --user daemon-reload
  fi
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
  network_handover
  enable_system
  enable_user
  greeter
}

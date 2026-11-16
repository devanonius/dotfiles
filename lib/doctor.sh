# shellcheck shell=bash
# dot doctor: check that this machine matches the repo and the desktop is
# healthy. Read-only: it never changes anything. Exit status 1 when a check
# fails; warnings are things worth a look that do not break the setup.

DOC_FAIL=0 DOC_WARN=0
ok()    { printf '  %sok%s    %s\n' "$C_GREEN" "$C_RESET" "$1"; }
bad()   { printf '  %sFAIL%s  %s\n' "$C_RED" "$C_RESET" "$1"; DOC_FAIL=$((DOC_FAIL + 1)); }
meh()   { printf '  %swarn%s  %s\n' "$C_YELLOW" "$C_RESET" "$1"; DOC_WARN=$((DOC_WARN + 1)); }
skip_() { printf '  -     %s\n' "$1"; }
section() { printf '%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"; }

doctor_links() {
  section "Configs"
  local stow_root broken=() link
  stow_root=$(readlink -f "$DOTFILES_DIR/stow")
  while IFS= read -r -d '' link; do
    [[ -e $link ]] && continue
    [[ $(readlink -m "$link") == "$stow_root"/* ]] && broken+=("$(pretty "$link")")
  done < <(find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null; find "$HOME/.config" "$HOME/.local" -type l -print0 2>/dev/null)
  if (( ${#broken[@]} )); then bad "broken links into the repo: ${broken[*]} (fix: dot restow)"
  else ok "no broken links into the repo"; fi

  local pkg missing=()
  for pkg in "$DOTFILES_DIR"/stow/*/; do
    pkg=$(basename "$pkg")
    while read -r file; do
      local rel
      rel=$(sed -E 's#(^|/)dot-#\1.#g' <<<"$file")   # stow --dotfiles naming
      [[ -L $HOME/$rel ]] || { missing+=("$pkg"); break; }
    done < <(cd "$DOTFILES_DIR/stow/$pkg" && find . -type f -printf '%P\n')
  done
  if (( ${#missing[@]} )); then bad "packages not linked: ${missing[*]} (fix: dot restow)"
  else ok "every stow package is linked"; fi

  local f
  for f in "$HOME/.config/wayle/layout.toml" "$HOME/.config/hypr/idle.conf"; do
    if [[ -e $f ]]; then ok "$(pretty "$f") -> $(basename "$(readlink -f "$f")")"
    else bad "$(pretty "$f") is missing (Wayle/hypridle cannot load their config; fix: dot restow)"; fi
  done

  if git -C "$DOTFILES_DIR" diff --quiet 2>/dev/null; then ok "repo has no uncommitted changes"
  else meh "repo has uncommitted changes (dot update refuses to run until they are committed)"; fi
}

doctor_theme() {
  section "Theme"
  # shellcheck source=lib/theme.sh
  source "$DOTFILES_DIR/lib/theme.sh"
  local id tpl missing=()
  id=$(theme_current)
  if [[ -n $id ]] && theme_exists "$id"; then ok "active theme: $id"
  else bad "no active theme (fix: dot theme set $DEFAULT_THEME)"; fi
  for tpl in "$DOTFILES_DIR"/stow/wal/.config/wal/templates/*; do
    [[ -f $WAL_CACHE/$(basename "$tpl") ]] || missing+=("$(basename "$tpl")")
  done
  if (( ${#missing[@]} )); then bad "not rendered: ${missing[*]} (fix: dot theme set ${id:-$DEFAULT_THEME})"
  else ok "every template is rendered in $(pretty "$WAL_CACHE")"; fi
  [[ -f $THEME_STATE/nvim.lua ]] && ok "Neovim theme file present" || meh "no Neovim theme file (Neovim uses tokyonight-night; fix: dot theme set ${id:-$DEFAULT_THEME})"
}

doctor_apps() {
  section "Apps"
  if has_cmd ghostty; then
    local out
    if out=$(ghostty +validate-config 2>&1); then ok "ghostty config valid"
    else bad "ghostty config: ${out//$'\n'/; }"; fi
  else skip_ "ghostty not installed"; fi

  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && has_cmd hyprctl; then
    local errs
    errs=$(hyprctl configerrors 2>&1 | sed '/^\s*$/d')
    if [[ -z $errs || $errs == ok ]]; then ok "Hyprland config has no errors"
    else bad "Hyprland config: ${errs//$'\n'/; }"; fi
  else skip_ "Hyprland not running here (config not checked)"; fi

  if has_cmd nvim; then
    if timeout 60 nvim --headless +qa >/dev/null 2>&1; then ok "Neovim starts"
    else bad "Neovim fails to start headless (run nvim to see the error)"; fi
  else skip_ "neovim not installed"; fi

  local log
  log=$(find "$HOME/.local/state/wayle" "$HOME/.cache/wayle" "$HOME/.local/share/wayle" -name 'wayle-shell*.log' -newermt '-1 day' 2>/dev/null | sort | tail -1 || true)
  if [[ -n $log ]]; then
    local n
    n=$(grep -ciE ' (WARN|ERROR) ' "$log" || true)
    if (( n )); then meh "Wayle logged $n warning(s)/error(s) today: grep -iE 'warn|error' $(pretty "$log")"
    else ok "Wayle log clean today"; fi
  else skip_ "no Wayle log from today"; fi
}

doctor_services() {
  section "Services"
  if ! has_cmd systemctl; then skip_ "no systemd"; return 0; fi
  local svc
  for svc in NetworkManager bluetooth upower power-profiles-daemon; do
    systemctl is-active --quiet "$svc" 2>/dev/null && ok "$svc running" || meh "$svc not running (sudo systemctl enable --now $svc)"
  done
  for svc in iwd systemd-networkd dhcpcd connman; do
    systemctl is-active --quiet "$svc" 2>/dev/null && bad "$svc runs next to NetworkManager (Wi-Fi fails; fix: sudo systemctl disable --now $svc, then reboot)"
  done
  if systemctl --user show-environment >/dev/null 2>&1; then
    for svc in hypridle hyprpolkitagent elephant; do
      if systemctl --user is-active --quiet "$svc" 2>/dev/null; then ok "$svc (user) running"
      elif systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then meh "$svc (user) enabled but not running (starts with the desktop session)"
      else bad "$svc (user) not enabled (fix: dot install --only services)"; fi
    done
  else skip_ "no systemd user session here (user services not checked)"; fi
}

doctor_hardware() {
  section "Hardware"
  # shellcheck source=lib/detect.sh
  source "$DOTFILES_DIR/lib/detect.sh"
  detect_all
  ok "machine: $( (( IS_LAPTOP )) && echo laptop || echo desktop), CPU $CPU_VENDOR"
  if (( HAS_NVIDIA )); then
    local param=/sys/module/nvidia_drm/parameters/modeset
    ok "NVIDIA: $(nvidia_summary)"
    if [[ ! -r $param ]]; then meh "NVIDIA driver not loaded (reboot after installing it?)"
    elif [[ $(<"$param") == Y ]]; then ok "NVIDIA kernel mode setting on"
    else bad "nvidia_drm.modeset is off (add nvidia_drm.modeset=1 to the kernel command line)"; fi
  fi
  case :$PATH: in
    *":$HOME/.local/bin:"*) ok "~/.local/bin on PATH" ;;
    *) meh "~/.local/bin not on PATH in this shell (dot scripts may not be found)" ;;
  esac
}

doctor_main() {
  doctor_links
  doctor_theme
  doctor_apps
  doctor_services
  doctor_hardware
  echo
  if (( DOC_FAIL )); then
    printf '%s%d problem(s)%s, %d warning(s)\n' "$C_RED" "$DOC_FAIL" "$C_RESET" "$DOC_WARN"
    return 1
  fi
  printf '%sAll checks passed%s (%d warning(s))\n' "$C_GREEN" "$C_RESET" "$DOC_WARN"
}

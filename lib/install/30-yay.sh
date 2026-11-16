# shellcheck shell=bash
# Stage 30: bootstrap yay, then install AUR packages from packages/aur.txt
# plus extra_packages.aur from the config.

bootstrap_yay() {
  changed "bootstrap yay from the AUR (yay-bin)"
  (( DRY_RUN )) && { info "[dry-run] git clone + makepkg -si yay-bin"; return 0; }

  local tmp
  tmp=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  has_cmd yay || die "yay bootstrap finished but yay is not on PATH"
}

stage_main() {
  if (( NO_PACKAGES )); then
    info "skipped (--no-packages)"
    return 0
  fi

  if has_cmd yay; then
    info "yay already installed"
  else
    bootstrap_yay
  fi

  local want=() missing=()
  mapfile -t want < <({ read_list "$DOTFILES_DIR/packages/aur.txt"; config_extra aur; } | sed '/^$/d' | dedupe)
  if (( ${#want[@]} == 0 )); then
    info "no AUR packages listed"
    return 0
  fi

  mapfile -t missing < <(missing_pkgs "${want[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "all ${#want[@]} AUR packages already installed"
    return 0
  fi

  changed "install ${#missing[@]} AUR package(s): ${missing[*]}"
  local args=(-S --needed)
  (( ASSUME_YES )) && args+=(--noconfirm)
  run yay "${args[@]}" "${missing[@]}" ||
    die "yay could not install the AUR packages above (exit $?); see its message above, then re-run."
}

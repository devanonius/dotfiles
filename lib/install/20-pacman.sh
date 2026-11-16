# shellcheck shell=bash
# Stage 20: install official-repo packages: the enabled modules
# (packages/<module>.txt), the hardware lists matching this machine
# (packages/hardware/), minus packages/exclude.txt, plus
# extra_packages.pacman from the config (never excluded: it is explicit).

stage_main() {
  if (( NO_PACKAGES )); then
    info "skipped (--no-packages)"
    return 0
  fi

  local module want=() extra=() missing=()
  while read -r module; do
    info "module: $module (packages/$module.txt)"
    mapfile -t -O "${#want[@]}" want < <(read_list "$DOTFILES_DIR/packages/$module.txt")
  done < <(enabled_modules)

  local hw
  if [[ $(config_get 'if has("hardware") then .hardware else true end') == true ]]; then
    while read -r hw; do
      info "hardware: $hw (packages/hardware/$hw.txt)"
      mapfile -t -O "${#want[@]}" want < <(read_list "$DOTFILES_DIR/packages/hardware/$hw.txt")
    done < <(hardware_lists)
  else
    info "hardware: skipped (\"hardware\": false)"
  fi

  local excluded=()
  mapfile -t excluded < <(read_list "$DOTFILES_DIR/packages/exclude.txt")
  if (( ${#excluded[@]} && ${#want[@]} )); then
    mapfile -t want < <(printf '%s\n' "${want[@]}" | grep -vxF -f <(printf '%s\n' "${excluded[@]}") || true)
  fi

  mapfile -t extra < <(config_extra pacman)
  if (( ${#extra[@]} )); then
    info "extra:  ${extra[*]}"
    want+=("${extra[@]}")
  fi
  mapfile -t want < <(printf '%s\n' "${want[@]}" | sed '/^$/d' | dedupe)

  if (( ${#want[@]} == 0 )); then
    info "no packages listed"
    return 0
  fi

  mapfile -t missing < <(missing_pkgs "${want[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "all ${#want[@]} packages already installed"
    return 0
  fi

  changed "install ${#missing[@]} package(s): ${missing[*]}"
  local args=(-Syu --needed)
  (( ASSUME_YES )) && args+=(--noconfirm)
  # -Syu, not -S: installing without a full upgrade is a partial upgrade,
  # which Arch does not support.
  run sudo pacman "${args[@]}" "${missing[@]}" ||
    die "pacman could not install the packages above (exit $?). Usually a question was answered 'no' (a conflict or a provider choice) or a package name does not exist; see pacman's message above, then re-run."
}

# shellcheck shell=bash
# Stage 30: bootstrap yay, then install AUR packages from packages/aur.txt
# plus extra_packages.aur from the config.
#
# Prebuilt first: compiling AUR packages takes long and is rarely needed.
#   - a listed package without -bin is replaced by <name>-bin when the AUR
#     has one
#   - AUR dependencies of the listed packages that the official repos do not
#     provide are added as <dep>-bin when that exists, so yay installs the
#     prebuilt package instead of building the dependency from source
#   - anything that still has to be built is named in a warning
# -git packages are kept as listed: that is an explicit choice.

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

aur_exists() { yay -Si --aur -- "$1" >/dev/null 2>&1; }

# Can pacman install this name (or a provider of it) from the official repos?
in_repos() { pacman -Sddp --print-format '%n' -- "$1" >/dev/null 2>&1; }

# Print one field ("Depends On", "Provides") of AUR packages, one name per
# line, version constraints removed. yay wraps long values onto indented
# continuation lines, so those are read as part of the field too.
aur_field() {
  local field=$1; shift
  yay -Si --aur -- "$@" 2>/dev/null |
    awk -v f="$field" '
      /^[^ \t][^:]*:/ { key = $0; sub(/ *:.*/, "", key); on = (key == f)
                         if (on) { v = $0; sub(/^[^:]*: */, "", v); print v }; next }
      on && /^[ \t]/  { print; next }
      { on = 0 }' |
    tr -s ' \t' '\n' | sed -E 's/[<>=].*$//' | grep -vx -e 'None' -e '' || true
}

# Print the package to install for a listed name: <name>-bin if it exists.
prefer_bin() {
  local pkg=$1
  case $pkg in
    *-bin|*-git) printf '%s\n' "$pkg"; return 0 ;;
  esac
  if aur_exists "$pkg-bin"; then
    info "$pkg: using the prebuilt $pkg-bin" >&2
    printf '%s\n' "$pkg-bin"
  else
    warn "$pkg has no prebuilt (-bin) package in the AUR; yay will build it from source"
    printf '%s\n' "$pkg"
  fi
}

# Add <dep>-bin for AUR dependencies of the targets (array AUR_TARGETS) that
# nothing else provides. Repeats for dependencies of what it added (3 levels).
add_prebuilt_deps() {
  local round dep added provided=()
  for round in 1 2 3; do
    added=0
    mapfile -t provided < <(printf '%s\n' "${AUR_TARGETS[@]}"; aur_field Provides "${AUR_TARGETS[@]}")
    while read -r dep; do
      printf '%s\n' "${provided[@]}" | grep -qxF -- "$dep" && continue   # a target provides it
      [[ -z $(missing_pkgs "$dep") ]] && continue                        # already installed
      in_repos "$dep" && continue                                         # official repos have it
      if aur_exists "$dep-bin"; then
        info "dependency $dep: using the prebuilt $dep-bin"
        AUR_TARGETS+=("$dep-bin")
        added=1
      elif (( round == 1 )); then
        warn "dependency $dep has no prebuilt (-bin) package in the AUR; yay will build it from source"
      fi
    done < <(aur_field "Depends On" "${AUR_TARGETS[@]}" | dedupe)
    (( added )) || break
  done
  return 0
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

  local listed=() missing=() pkg
  local nvidia=()
  if [[ $(config_get 'if has("hardware") then .hardware else true end') == true ]]; then
    mapfile -t nvidia < <(nvidia_packages aur "$(config_get '.nvidia_driver // "auto"')")
  fi
  mapfile -t listed < <({ read_list "$DOTFILES_DIR/packages/aur.txt"; config_extra aur; printf '%s\n' "${nvidia[@]}"; } | sed '/^$/d' | dedupe)
  if (( ${#listed[@]} == 0 )); then
    info "no AUR packages listed"
    return 0
  fi

  mapfile -t missing < <(missing_pkgs "${listed[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "all ${#listed[@]} AUR packages already installed"
    return 0
  fi

  if ! has_cmd yay; then   # dry run before yay exists: no AUR lookups possible
    changed "install ${#missing[@]} AUR package(s): ${missing[*]}"
    return 0
  fi

  AUR_TARGETS=()
  for pkg in "${missing[@]}"; do
    AUR_TARGETS+=("$(prefer_bin "$pkg")")
  done
  add_prebuilt_deps
  mapfile -t AUR_TARGETS < <(printf '%s\n' "${AUR_TARGETS[@]}" | dedupe)
  mapfile -t AUR_TARGETS < <(missing_pkgs "${AUR_TARGETS[@]}")
  if (( ${#AUR_TARGETS[@]} == 0 )); then
    info "all AUR packages already installed (as prebuilt variants)"
    return 0
  fi

  changed "install ${#AUR_TARGETS[@]} AUR package(s): ${AUR_TARGETS[*]}"
  local args=(-S --needed)
  (( ASSUME_YES )) && args+=(--noconfirm)
  run yay "${args[@]}" "${AUR_TARGETS[@]}" ||
    die "yay could not install the AUR packages above (exit $?); see its message above, then re-run."
}

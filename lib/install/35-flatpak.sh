# shellcheck shell=bash
# Stage 35: install extra_packages.flatpak from the config.
# Does nothing (and installs no flatpak) when that list is empty.

stage_main() {
  if (( NO_PACKAGES )); then
    info "skipped (--no-packages)"
    return 0
  fi

  local want=() missing=() id
  mapfile -t want < <(config_extra flatpak | dedupe)
  if (( ${#want[@]} == 0 )); then
    info "no flatpak packages listed"
    return 0
  fi

  local scope remote url
  scope=$(config_get '.flatpak.scope // "user"')
  remote=$(config_get '.flatpak.remote // "flathub"')
  url=$(config_get '.flatpak.remote_url // "https://dl.flathub.org/repo/flathub.flatpakrepo"')
  # System-wide installs need root; per-user installs must not use it.
  local as=()
  [[ $scope == system ]] && as=(sudo)

  if ! has_cmd flatpak; then
    changed "install flatpak"
    local args=(-Syu --needed)
    (( ASSUME_YES )) && args+=(--noconfirm)
    run sudo pacman "${args[@]}" flatpak
    if (( DRY_RUN )); then
      changed "add flatpak remote $remote ($scope)"
      changed "install ${#want[@]} flatpak(s) ($scope): ${want[*]}"
      return 0
    fi
  fi

  if ! flatpak "--$scope" remotes --columns=name 2>/dev/null | grep -qx "$remote"; then
    changed "add flatpak remote $remote ($scope)"
    run "${as[@]}" flatpak remote-add "--$scope" --if-not-exists "$remote" "$url"
  fi

  for id in "${want[@]}"; do
    flatpak "--$scope" info "$id" >/dev/null 2>&1 || missing+=("$id")
  done
  if (( ${#missing[@]} == 0 )); then
    info "all ${#want[@]} flatpaks already installed ($scope)"
    return 0
  fi

  changed "install ${#missing[@]} flatpak(s) ($scope): ${missing[*]}"
  run "${as[@]}" flatpak install "--$scope" --noninteractive -y "$remote" "${missing[@]}"
}

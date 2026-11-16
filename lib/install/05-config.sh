# shellcheck shell=bash
# Stage 05: load and validate the install config (see lib/config.sh).

stage_main() {
  config_load
  local file
  for file in "${CONFIG_SOURCES[@]}"; do
    info "config:   $(pretty "$file")"
  done
  info "modules:  $(config_get '.modules // {} | to_entries | map("\(.key)=\(.value)") | join(" ")')"
  info "extras:   pacman $(config_extra pacman | wc -l), aur $(config_extra aur | wc -l), flatpak $(config_extra flatpak | wc -l)"
}

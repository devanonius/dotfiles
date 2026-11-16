# shellcheck shell=bash
# Stage 55: install system files (outside $HOME) for enabled modules.
#
# system/<module>/ mirrors the root of the filesystem:
#   system/keyd/etc/keyd/default.conf  ->  /etc/keyd/default.conf
# Files are copied with sudo, not linked: services read them at boot, when a
# home folder may not be mounted, and root-owned files should not point into
# a user's home. The repo copy is the source of truth; edit it, then re-run
# `dot install` (or `dot install --only system`).
#
# system/<module>.service (optional) lists systemd units, one per line, to
# enable and to restart when that module's files change.
#
# DOTFILES_ROOT exists only so tests can install into a fake root.
: "${DOTFILES_ROOT:=}"

# Compare repo file and installed file, with sudo if it is not readable.
same_file() {
  [[ -e $2 ]] || return 1
  if [[ -r $2 ]]; then cmp -s "$1" "$2"; else sudo cmp -s "$1" "$2"; fi
}

install_module_files() {
  local module=$1 backup=$2 dir="$DOTFILES_DIR/system/$1" rel dest
  MODULE_CHANGED=0
  while read -r rel; do
    dest="$DOTFILES_ROOT/$rel"
    same_file "$dir/$rel" "$dest" && continue
    if [[ -e $dest ]]; then
      changed "back up /$rel"
      # Read with sudo, write as the user, so the backup stays deletable.
      if (( DRY_RUN )); then
        info "[dry-run] sudo cat $dest > $backup/$rel"
      else
        mkdir -p "$(dirname "$backup/$rel")"
        sudo cat "$dest" > "$backup/$rel"
      fi
    fi
    changed "install /$rel ($module)"
    run sudo install -D -m 644 "$dir/$rel" "$dest"
    MODULE_CHANGED=1
  done < <(cd "$dir" && find . -type f ! -name '.gitkeep' -printf '%P\n' | sort)
}

handle_services() {
  local module=$1 unit
  [[ -f $DOTFILES_DIR/system/$module.service ]] || return 0
  while read -r unit; do
    if ! has_cmd systemctl; then
      info "$unit: systemctl not available, skipped"
    elif ! systemctl is-enabled --quiet "$unit.service" 2>/dev/null; then
      changed "enable and start $unit"
      run sudo systemctl enable --now "$unit.service"
    elif (( MODULE_CHANGED )); then
      changed "restart $unit (its files changed)"
      run sudo systemctl restart "$unit.service"
    fi
  done < <(read_list "$DOTFILES_DIR/system/$module.service")
}

stage_main() {
  local module any=0 backup
  backup="$DOTFILES_STATE/backup/$(date +%Y%m%d-%H%M%S)/system"
  while read -r module; do
    [[ -d $DOTFILES_DIR/system/$module ]] || continue
    any=1
    info "module: $module (system/$module/)"
    install_module_files "$module" "$backup"
    handle_services "$module"
  done < <(enabled_modules)
  (( any )) || info "no enabled module has system files"
  return 0
}

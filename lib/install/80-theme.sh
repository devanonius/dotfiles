# shellcheck shell=bash
# Stage 80: apply the active theme (the default on a first install). Only
# re-applies when the theme or a template changed, so a re-run with nothing
# new is a no-op. Switching themes later: `dot theme set <id>`.

stage_main() {
  # shellcheck source=lib/theme.sh
  source "$DOTFILES_DIR/lib/theme.sh"

  local id fingerprint applied=''
  id=$(theme_current)
  theme_exists "${id:-none}" || id=$DEFAULT_THEME
  theme_exists "$id" || die "default theme $id not found in themes/"

  if ! has_cmd wal; then
    (( DRY_RUN )) && { changed "apply theme $id (pywal16 is installed by stage 30)"; return 0; }
    die "wal (pywal16) is not installed (python-pywal16 is in packages/aur.txt)"
  fi

  fingerprint=$(theme_fingerprint "$id")
  [[ -f $THEME_STATE/fingerprint ]] && applied=$(<"$THEME_STATE/fingerprint")
  if [[ $fingerprint == "$applied" && -f $WAL_CACHE/colors.json ]]; then
    info "theme $id is applied and up to date"
    return 0
  fi

  changed "apply theme $id"
  (( DRY_RUN )) && return 0
  theme_set "$id"
}

# shellcheck shell=bash
# Stage 45: run one-time migrations from migrations/ (see migrations/README.md)
# before configs are linked. Each runs once per machine.

MIGRATIONS_STATE="$DOTFILES_STATE/migrations.txt"

stage_main() {
  local files=() file name pending=0
  mapfile -t files < <(find "$DOTFILES_DIR/migrations" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.sh' 2>/dev/null | sort)

  # First run on this machine: nothing older to migrate from.
  if [[ ! -f $MIGRATIONS_STATE ]]; then
    changed "record ${#files[@]} migration(s) as done (first run on this machine)"
    (( DRY_RUN )) && return 0
    mkdir -p "$DOTFILES_STATE"
    for file in "${files[@]}"; do basename "$file" .sh; done > "$MIGRATIONS_STATE"
    return 0
  fi

  for file in "${files[@]}"; do
    name=$(basename "$file" .sh)
    grep -qxF "$name" "$MIGRATIONS_STATE" && continue
    pending=1
    changed "migration $name"
    unset -f migrate
    # shellcheck source=/dev/null
    source "$file"
    declare -F migrate >/dev/null || die "migration $name defines no migrate() function"
    migrate || die "migration $name failed; fix the cause and re-run (it has not been recorded)"
    (( DRY_RUN )) || printf '%s\n' "$name" >> "$MIGRATIONS_STATE"
  done
  (( pending )) || info "no pending migrations"
}

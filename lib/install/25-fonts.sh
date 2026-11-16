# shellcheck shell=bash
# Stage 25: install the Nerd Fonts chosen in the config ("fonts").
#   list  -> exactly those
#   all   -> every font in packages/fonts/nerd-fonts.txt
#   none  -> nothing
#   ask   -> pick once from a list (fzf); the choice is remembered in
#            $DOTFILES_STATE/fonts.txt so re-runs do not ask again.
#            `dot fonts` forgets it and asks again.
# Fonts are never uninstalled by this stage.

FONT_CATALOG_REL=packages/fonts/nerd-fonts.txt

# True when a person can answer an interactive picker.
have_terminal() { (( ! ASSUME_YES )) && { : >/dev/tty; } 2>/dev/null; }

# Print the fonts picked in fzf (Tab marks, Enter confirms).
pick_fonts() {
  local catalog=$1
  read_list "$catalog" | fzf --multi --height=60% --reverse \
    --header='Nerd Fonts: Tab to mark, Enter to confirm (Enter with none marked = no extra fonts)' \
    --prompt='font> ' || true
}

stage_main() {
  if (( NO_PACKAGES )); then
    info "skipped (--no-packages)"
    return 0
  fi

  local catalog="$DOTFILES_DIR/$FONT_CATALOG_REL" state="$DOTFILES_STATE/fonts.txt"
  local mode want=() missing=()
  mode=$(config_fonts_mode)

  case $mode in
    none) info "no extra fonts (\"fonts\": \"none\")"; return 0 ;;
    all)  mapfile -t want < <(read_list "$catalog") ;;
    list) mapfile -t want < <(config_fonts_list) ;;
    ask)
      if [[ -f $state ]]; then
        info "using the fonts picked earlier ($(pretty "$state"); 'dot fonts' to change)"
        mapfile -t want < <(read_list "$state")
      elif (( DRY_RUN )); then
        info "would ask which Nerd Fonts to install"
        return 0
      elif ! have_terminal; then
        info "no terminal to ask which fonts to install; skipped (run 'dot fonts' later, or set \"fonts\" in the config)"
        return 0
      else
        require_cmd fzf
        mapfile -t want < <(pick_fonts "$catalog")
        changed "remember font choice (${#want[@]} font(s)) in $(pretty "$state")"
        mkdir -p "$(dirname "$state")"
        printf '%s\n' "${want[@]}" | sed '/^$/d' > "$state"
      fi
      ;;
  esac

  mapfile -t want < <(printf '%s\n' "${want[@]}" | sed '/^$/d' | dedupe)
  if (( ${#want[@]} == 0 )); then
    info "no extra fonts selected"
    return 0
  fi

  mapfile -t missing < <(missing_pkgs "${want[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "all ${#want[@]} selected fonts already installed"
    return 0
  fi

  changed "install ${#missing[@]} font(s): ${missing[*]}"
  local args=(-Syu --needed)
  (( ASSUME_YES )) && args+=(--noconfirm)
  run sudo pacman "${args[@]}" "${missing[@]}"
}

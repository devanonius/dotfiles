# shellcheck shell=bash
# Stage 05: load and validate the install config (see lib/config.sh).
#
# First run without a config (no -c, no ~/.config/dotfiles/config.json) and
# with someone at the terminal: ask what to install and save the answers to
# ~/.config/dotfiles/config.json, so later runs and `dot update` do not ask.
# Plain bash reading /dev/tty: nothing here may need packages that are not
# installed yet (the installer may be running from `curl ... | bash`).

# One-line description of a module: its "# Description:" line, else the
# first comment line of its file.
module_description() {
  local f="$DOTFILES_DIR/packages/$1.txt" d
  d=$(sed -n 's/^# *Description: *//p' "$f" | head -1)
  [[ -n $d ]] || d=$(sed -n '1s/^# *//p' "$f")
  printf '%s\n' "$d"
}

ask_yes_no() {   # ask_yes_no QUESTION DEFAULT(y|n) -> true for yes
  local q=$1 def=$2 reply hint="[Y/n]"
  [[ $def == n ]] && hint="[y/N]"
  read -r -p "    $q $hint " reply </dev/tty || reply=
  reply=${reply:-$def}
  [[ $reply =~ ^[Yy] ]]
}

first_run_menu() {
  local file=$CONFIG_LOCAL
  log "First run: choose what to install (Enter keeps the default)"
  echo "    Answers are saved to $(pretty "$file"); edit it or delete it to be asked again." >/dev/tty

  local modules="{}" name
  echo >/dev/tty
  echo "  Package groups:" >/dev/tty
  for name in $(jq -r '.modules // {} | keys[]' "$CONFIG_DEFAULT"); do
    [[ -f $DOTFILES_DIR/packages/$name.txt ]] || continue
    echo "    $name: $(module_description "$name")" >/dev/tty
    if ask_yes_no "install $name?" y; then
      modules=$(jq --arg n "$name" '. + {($n): true}' <<<"$modules")
    else
      modules=$(jq --arg n "$name" '. + {($n): false}' <<<"$modules")
    fi
  done

  # shellcheck source=lib/browser.sh
  source "$DOTFILES_DIR/lib/browser.sh"
  local ids=() i=1 id choice browser=ask
  mapfile -t ids < <(browser_ids)
  echo >/dev/tty
  echo "  Web browser (gets Vimium and the theme colors):" >/dev/tty
  for id in "${ids[@]}"; do
    printf '    %d) %s\n' "$i" "$(browser_get "$id" name)" >/dev/tty
    i=$((i + 1))
  done
  printf '    %d) none\n' "$i" >/dev/tty
  read -r -p "    number [Enter: decide later] " choice </dev/tty || choice=
  if [[ $choice =~ ^[0-9]+$ ]]; then
    if (( choice >= 1 && choice <= ${#ids[@]} )); then browser=${ids[choice - 1]}
    elif (( choice == ${#ids[@]} + 1 )); then browser=none
    fi
  fi

  local fonts=ask
  echo >/dev/tty
  echo "  Nerd Fonts (JetBrains Mono is always installed):" >/dev/tty
  echo "    1) pick from the list in a moment   2) all   3) no extra fonts" >/dev/tty
  read -r -p "    number [Enter: 1] " choice </dev/tty || choice=
  case $choice in
    2) fonts=all ;;
    3) fonts=none ;;
  esac

  mkdir -p "$(dirname "$file")"
  jq -n --arg schema "$DOTFILES_DIR/config/config.schema.json" --argjson modules "$modules" \
        --arg browser "$browser" --arg fonts "$fonts" \
    '{"$schema": $schema, modules: $modules, browser: $browser, fonts: $fonts}' > "$file"
  changed "saved first-run choices to $(pretty "$file")"
}

stage_main() {
  if [[ -z $CONFIG_FILE && ! -f $CONFIG_LOCAL ]]; then
    if (( DRY_RUN )); then
      info "first run: a real run asks which package groups, browser and fonts to install"
    elif (( ! ASSUME_YES )) && { : >/dev/tty; } 2>/dev/null; then
      first_run_menu
    else
      info "no config and nobody to ask: using config/default.json"
    fi
  fi

  config_load
  local file
  for file in "${CONFIG_SOURCES[@]}"; do
    info "config:   $(pretty "$file")"
  done
  info "modules:  $(config_get '.modules // {} | to_entries | map("\(.key)=\(.value)") | join(" ")')"
  info "extras:   pacman $(config_extra pacman | wc -l), aur $(config_extra aur | wc -l), flatpak $(config_extra flatpak | wc -l)"
}

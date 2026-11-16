# shellcheck shell=bash
# Install config: which modules and extra packages to install.
#
# Files are merged in this order, later ones winning (objects merge,
# arrays replace):
#   1. config/default.json                 (tracked, always)
#   2. ~/.config/dotfiles/config.json      (this machine, untracked, if present)
#   3. the file given with -c/--config     (if any)

CONFIG_DEFAULT="$DOTFILES_DIR/config/default.json"
CONFIG_LOCAL="$DOTFILES_CONFIG/config.json"
: "${CONFIG_FILE:=}"
CONFIG_JSON=''
CONFIG_SOURCES=()

# Fail with every problem in one file, so a typo is reported by name.
config_validate_file() {
  local file=$1 problems
  [[ -r $file ]] || die "config file not readable: $file"
  if ! jq empty "$file" >/dev/null 2>&1; then
    die "$file is not valid JSON: $(jq empty "$file" 2>&1 | head -n 1)"
  fi
  problems=$(jq -r -f "$DOTFILES_DIR/lib/config-validate.jq" "$file")
  [[ -z $problems ]] || die "invalid config in $file:"$'\n'"$(sed 's/^/      - /' <<<"$problems")"
}

# Modules must name an existing packages/<name>.txt; base and aur are implicit.
config_validate_modules() {
  local name
  while read -r name; do
    case $name in
      base|aur) die "modules.$name: '$name' is always installed and cannot be listed in modules" ;;
      exclude)  die "modules.exclude: packages/exclude.txt is not a module" ;;
    esac
    [[ -f $DOTFILES_DIR/packages/$name.txt ]] || die "modules.$name: unknown module (no packages/$name.txt)"
  done < <(jq -r '.modules // {} | keys[]' <<<"$CONFIG_JSON")
}

config_load() {
  require_cmd jq
  CONFIG_SOURCES=("$CONFIG_DEFAULT")
  [[ -f $CONFIG_LOCAL ]] && CONFIG_SOURCES+=("$CONFIG_LOCAL")
  if [[ -n $CONFIG_FILE && $CONFIG_FILE != "$CONFIG_LOCAL" ]]; then
    CONFIG_SOURCES+=("$CONFIG_FILE")
  fi

  local file
  for file in "${CONFIG_SOURCES[@]}"; do
    config_validate_file "$file"
  done
  CONFIG_JSON=$(jq -s 'reduce .[] as $c ({}; . * $c) | del(."$schema")' "${CONFIG_SOURCES[@]}")
  config_validate_modules
  config_validate_fonts
}

# config_get JQ_FILTER : raw output of a filter on the merged config.
config_get() { jq -r "$1" <<<"$CONFIG_JSON"; }

# config_extra pacman|aur|flatpak : extra package names, one per line.
config_extra() { jq -r --arg k "$1" '.extra_packages[$k] // [] | .[]' <<<"$CONFIG_JSON"; }

# Print the pacman modules to install on this machine, base first.
enabled_modules() {
  echo base
  jq -r '.modules // {} | to_entries[] | select(.value == true or .value == "auto") | .key' <<<"$CONFIG_JSON"
}

# Fonts from the config: a list, or the words ask / all / none.
config_fonts_mode() { jq -r '.fonts // "ask" | if type == "array" then "list" else . end' <<<"$CONFIG_JSON"; }
config_fonts_list() { jq -r '.fonts | if type == "array" then .[] else empty end' <<<"$CONFIG_JSON"; }

# Font names in the config must be in the catalog, to catch typos early.
config_validate_fonts() {
  local font catalog="$DOTFILES_DIR/packages/fonts/nerd-fonts.txt"
  while read -r font; do
    read_list "$catalog" | grep -qx -- "$font" || die "fonts: '$font' is not in packages/fonts/nerd-fonts.txt"
  done < <(config_fonts_list)
}

# shellcheck shell=bash
# Stage 32: the web browser. Config key "browser":
#   "ask" (default) -> pick once from browser/browsers.json; remembered in
#                      $DOTFILES_STATE/browser.txt (`dot browser set <id>` changes it)
#   "<id>"          -> that browser
#   "none"          -> skip
# Then: install it (repo or AUR), install the extensions in
# browser/extensions.json through the browser's enterprise policy, make it
# the default browser, and color its toolbar from the theme (Chromium family).
# Runs after the AUR stage (several browsers are AUR -bin packages).

# shellcheck source=lib/browser.sh
source "$DOTFILES_DIR/lib/browser.sh"

have_terminal() { (( ! ASSUME_YES )) && { : >/dev/tty; } 2>/dev/null; }

pick_browser() {
  local id
  while read -r id; do
    printf '%s\t%s\n' "$id" "$(browser_get "$id" name)"
  done < <(browser_ids) | { cat; printf 'none\tno browser\n'; } |
    fzf --height=40% --reverse --with-nth=2 --delimiter='\t' \
      --header='Browser: Enter to choose (gets Vimium and the theme colors)' --prompt='browser> ' |
    cut -f1 || true
}

resolve_choice() {
  local want
  want=$(config_get '.browser // "ask"')
  case $want in
    ask)
      if [[ -f $BROWSER_STATE ]]; then
        browser_current
      elif (( DRY_RUN )) || ! have_terminal; then
        echo ask-later
      else
        require_cmd fzf
        local id
        id=$(pick_browser)
        echo "${id:-none}"
      fi ;;
    *) echo "$want" ;;
  esac
}

install_browser() {
  local id=$1 pkg source
  pkg=$(browser_get "$id" package)
  source=$(browser_get "$id" source)
  if (( NO_PACKAGES )); then
    info "$pkg: not installed (--no-packages)"
    return 0
  fi
  if [[ -z $(missing_pkgs "$pkg") ]]; then
    info "$pkg installed"
    return 0
  fi
  changed "install $pkg"
  local args=(-S --needed)
  (( ASSUME_YES )) && args+=(--noconfirm)
  if [[ $source == aur ]]; then
    run yay "${args[@]}" "$pkg" || die "yay could not install $pkg (see its message above)"
  else
    run sudo pacman -Syu --needed "${args[@]:2}" "$pkg" || die "pacman could not install $pkg (see its message above)"
  fi
}

# Write a system file only when its content differs.
put_system_file() {
  local content=$1 dest=$2 mode=${3:-644} owner=${4:-root}
  if [[ -f $dest ]] && [[ $(cat "$dest") == "$content" ]]; then
    return 0
  fi
  changed "write $dest"
  (( DRY_RUN )) && return 0
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  run sudo install -D -m "$mode" -o "$owner" "$tmp" "$dest"
  rm -f "$tmp"
}

write_policies() {
  local id=$1 family
  family=$(browser_get "$id" family)
  if [[ $family == chromium ]]; then
    local dir
    dir=$(browser_get "$id" policy_dir)
    put_system_file "$(browser_chromium_extensions)" "$dir/dotfiles-extensions.json"
    # Owned by the user: the theme engine rewrites it on every theme switch.
    if [[ ! -O $dir/dotfiles-theme.json ]]; then
      changed "create $dir/dotfiles-theme.json (owned by $USER, for theme colors)"
      (( DRY_RUN )) || { local tmp; tmp=$(mktemp); echo '{}' > "$tmp"
        run sudo install -D -m 644 -o "$USER" "$tmp" "$dir/dotfiles-theme.json"; rm -f "$tmp"; }
    fi
  else
    local app shipped
    app=$(browser_get "$id" app)
    shipped=$(browser_shipped_policies "$id")
    [[ -n $shipped ]] && info "merging the policies $id ships ($shipped)"
    put_system_file "$(browser_firefox_policies "$shipped")" "/etc/$app/policies/policies.json"
  fi
}

set_default() {
  local id=$1 desktop
  desktop=$(browser_desktop_file "$id")
  if [[ -z $desktop ]]; then
    (( DRY_RUN )) && { info "would set $id as the default browser"; return 0; }
    warn "no .desktop file found for $id; default browser not set"
    return 0
  fi
  if has_cmd xdg-settings && [[ $(xdg-settings get default-web-browser 2>/dev/null) == "$desktop" ]]; then
    info "default browser: $desktop"
    return 0
  fi
  changed "default browser: $desktop"
  run xdg-settings set default-web-browser "$desktop"
}

stage_main() {
  local id
  id=$(resolve_choice)
  case $id in
    none)      info "no browser (\"browser\": \"none\" or none picked)"; return 0 ;;
    ask-later) info "would ask which browser to use (or run: dot browser set <id>)"; return 0 ;;
  esac
  browser_exists "$id" || die "unknown browser '$id' (choose from: $(browser_ids | tr '\n' ' ')none)"

  if [[ $(browser_current) != "$id" ]]; then
    changed "remember browser $id in $(pretty "$BROWSER_STATE")"
    (( DRY_RUN )) || { mkdir -p "$DOTFILES_STATE"; printf '%s\n' "$id" > "$BROWSER_STATE"; }
  fi
  info "browser: $(browser_get "$id" name)"

  install_browser "$id"
  write_policies "$id"
  set_default "$id"
  (( DRY_RUN )) || browser_theme_apply
}

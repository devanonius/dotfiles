# shellcheck shell=bash
# Browser helpers shared by stage 32-browser, `dot browser` and the theme
# engine. Data: browser/browsers.json and browser/extensions.json.

BROWSERS_JSON="$DOTFILES_DIR/browser/browsers.json"
EXTENSIONS_JSON="$DOTFILES_DIR/browser/extensions.json"
BROWSER_STATE="$DOTFILES_STATE/browser.txt"

browser_ids()      { jq -r 'keys_unsorted[]' "$BROWSERS_JSON"; }
browser_exists()   { jq -e --arg b "$1" 'has($b)' "$BROWSERS_JSON" >/dev/null; }
browser_get()      { jq -r --arg b "$1" --arg k "$2" '.[$b][$k] // empty' "$BROWSERS_JSON"; }
browser_current()  { [[ -f $BROWSER_STATE ]] && cat "$BROWSER_STATE"; return 0; }

# The .desktop file the package installs (for xdg-settings).
browser_desktop_file() {
  local pkg
  pkg=$(browser_get "$1" package)
  has_cmd pacman || return 0
  pacman -Qlq "$pkg" 2>/dev/null | grep -m1 '^/usr/share/applications/.*\.desktop$' | xargs -r basename
}

# Firefox family: the policies the browser ships itself (to merge with ours).
browser_shipped_policies() {
  local pkg
  pkg=$(browser_get "$1" package)
  has_cmd pacman || return 0
  pacman -Qlq "$pkg" 2>/dev/null | grep -m1 '/distribution/policies\.json$' || true
}

# Chromium family: {"ExtensionInstallForcelist": [...]}
browser_chromium_extensions() {
  jq '{ExtensionInstallForcelist: [.[] | select(.chromium_id) | "\(.chromium_id);https://clients2.google.com/service/update2/crx"]}' "$EXTENSIONS_JSON"
}

# Firefox family: shipped policies (if any) with our extensions merged in.
browser_firefox_policies() {
  local shipped=$1
  local ours
  ours=$(jq '{policies: {ExtensionSettings: (map(select(.firefox_id)) | map({key: .firefox_id, value: {
      installation_mode: "force_installed",
      install_url: "https://addons.mozilla.org/firefox/downloads/latest/\(.amo_slug)/latest.xpi"}}) | from_entries)}}' "$EXTENSIONS_JSON")
  if [[ -n $shipped && -r $shipped ]]; then
    jq -s '.[0] * .[1]' "$shipped" <(printf '%s' "$ours")
  else
    printf '%s\n' "$ours"
  fi
}

# Toolbar color for Chromium-family browsers, from the active theme. The file
# is owned by the user (created by stage 32), so no sudo is needed here.
# Chrome/Chromium 142+ apply it at once with --refresh-platform-policy;
# otherwise on the next browser start.
browser_theme_apply() {
  local id dir file bg bin
  id=$(browser_current)
  [[ -n $id ]] && browser_exists "$id" || return 0
  [[ $(browser_get "$id" family) == chromium ]] || return 0
  dir=$(browser_get "$id" policy_dir)
  file="$dir/dotfiles-theme.json"
  [[ -w $file ]] || return 0
  bg=$(jq -r '.special.background' "${WAL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/wal}/colors.json" 2>/dev/null) || return 0
  [[ $bg == \#* ]] || return 0
  printf '{\n  "BrowserThemeColor": "%s"\n}\n' "$bg" > "$file"
  bin=$(browser_get "$id" bin)
  if pgrep -x "$(basename "$bin")" >/dev/null 2>&1 || pgrep -f "/$bin( |$)" >/dev/null 2>&1; then
    timeout 5 "$bin" --refresh-platform-policy --no-startup-window >/dev/null 2>&1 &
  fi
  return 0
}

# Copy the Vimium CSS for the active theme to the clipboard.
browser_vimium_css() {
  local css="${WAL_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/wal}/vimium.css"
  [[ -f $css ]] || die "no rendered Vimium CSS yet (run: dot theme set <id>)"
  if has_cmd wl-copy && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    wl-copy < "$css"
    log "Vimium CSS copied: Vimium options > CSS for Vimium UI > paste > Save"
    has_cmd notify-send && notify-send -a dotfiles "Vimium CSS copied" "Vimium options → CSS for Vimium UI → paste → Save" || true
  else
    cat "$css"
  fi
}

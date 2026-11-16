#!/usr/bin/env bash
# End-to-end test of the installer on a real Arch system: WSL, Docker,
# CI or a VM. Run as a normal user with sudo. It really installs packages.
#
# Usage: tests/run.sh [CONFIG]      (default: tests/ci.json, a small set)
#        tests/run.sh --static      only the checks that change nothing
set -Euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
STATIC_ONLY=0
CONFIG=$REPO/tests/ci.json
case ${1:-} in
  --static) STATIC_ONLY=1 ;;
  '') ;;
  *) CONFIG=$(readlink -f "$1") ;;
esac

PASS=0 FAIL=0 SKIP=0
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

pass() { PASS=$((PASS + 1)); printf '  \e[32mPASS\e[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \e[31mFAIL\e[0m %s\n' "$1"; sed 's/^/       | /' "$OUT" | tail -n 25; }
skip() { SKIP=$((SKIP + 1)); printf '  \e[33mSKIP\e[0m %s (%s)\n' "$1" "$2"; }

# check NAME COMMAND... : pass when the command exits 0.
check() { local name=$1; shift; if "$@" >"$OUT" 2>&1; then pass "$name"; else fail "$name"; fi; }
# check_fails NAME PATTERN COMMAND... : pass when it exits non-zero and prints PATTERN.
check_fails() {
  local name=$1 pattern=$2; shift 2
  if "$@" >"$OUT" 2>&1; then fail "$name (expected failure)"
  elif grep -q -- "$pattern" "$OUT"; then pass "$name"
  else fail "$name (missing: $pattern)"; fi
}

cd "$REPO" || exit 1
echo "dotfiles tests: $REPO  (config: ${CONFIG#"$REPO"/})"
[[ $EUID -ne 0 ]] || { echo "run as a normal user with sudo, not root"; exit 2; }

echo "== static"
# The static checks are dry runs; let them pass the Arch check on any Linux.
export DOTFILES_ALLOW_NON_ARCH=1
syntax() { local f; for f in install.sh bin/* lib/*.sh lib/install/*.sh tests/*.sh tools/*.sh; do bash -n "$f" || return 1; done; }
check "bash syntax" syntax

if ! command -v shellcheck >/dev/null && [[ -f /etc/arch-release ]] && (( ! STATIC_ONLY )); then
  sudo pacman -S --needed --noconfirm shellcheck >/dev/null 2>&1
fi
if command -v shellcheck >/dev/null; then
  check "shellcheck" shellcheck -x -e SC1091 install.sh bin/* lib/*.sh lib/install/*.sh tests/*.sh tools/*.sh
else
  skip "shellcheck" "not installed"
fi

if command -v jq >/dev/null; then
  validate_all() { local f; for f in config/default.json config/example.json tests/ci.json; do
    [[ -z $(jq -r -f lib/config-validate.jq "$f") ]] || { echo "$f invalid"; jq -r -f lib/config-validate.jq "$f"; return 1; }; done; }
  check "shipped configs are valid" validate_all

  bad=$(mktemp --suffix=.json)
  printf '{"modules":{"desktop":"yes"},"extra_packages":{"pacman":["--force"]},"typo":1}\n' >"$bad"
  check_fails "bad config is rejected with reasons" "unknown key: typo" bash install.sh --dry-run --no-packages -c "$bad"
  check_fails "bad package name is rejected" "invalid package name" bash install.sh --dry-run --no-packages -c "$bad"
  printf '{"modules":{"nosuchmodule":true}}\n' >"$bad"
  check_fails "unknown module is rejected" "unknown module" bash install.sh --dry-run --no-packages -c "$bad"
  printf '{"fonts":["ttf-not-a-real-font-nerd"]}\n' >"$bad"
  check_fails "font not in the catalog is rejected" "not in packages/fonts" bash install.sh --dry-run --no-packages -c "$bad"
  printf '{"hardware":"yes","fonts":"some"}\n' >"$bad"
  check_fails "wrong hardware/fonts values are rejected" "hardware must be true or false" bash install.sh --dry-run --no-packages -c "$bad"
  rm -f "$bad"
else
  skip "config validation" "jq not installed"
fi
LUAC=$(command -v luac || command -v texluac || true)
if [[ -n $LUAC ]]; then
  lua_syntax() { local f; for f in stow/hypr/.config/hypr/*.lua; do "$LUAC" -p "$f" || return 1; done; }
  check "Hyprland Lua syntax" lua_syntax
else
  skip "Hyprland Lua syntax" "no luac (pacman -S lua)"
fi
# Hyprland's Lua config rejects hyprlang leftovers: dotted keys like
# ["col.active_border"] and gradient strings like "rgb(..) rgb(..) 45deg".
no_hyprlang_colors() {
  ! grep -nE '\["col\.|[0-9]+deg"' stow/hypr/.config/hypr/*.lua stow/wal/.config/wal/templates/*.lua | grep -v '^\S*:[0-9]*:\s*--'
}
check "no hyprlang-style colors in the Hyprland Lua config" no_hyprlang_colors

themes_valid() {
  local d id
  for d in themes/*/; do
    id=$(basename "$d")
    [[ -f $d/colors.json && -f $d/theme.json ]] || { echo "$id: needs colors.json and theme.json"; return 1; }
    jq -e '(.name|type=="string") and (.family|type=="string") and (.variant=="dark" or .variant=="light")
           and (.nvim_scheme|type=="string") and (.source|type=="string")' "$d/theme.json" >/dev/null ||
      { echo "$id: theme.json needs name, family, variant (dark|light), nvim_scheme, source"; return 1; }
  done
}
check "themes have valid metadata" themes_valid
check "every template renders with every theme" python3 tests/fake-wal.py --check stow/wal/.config/wal/templates themes/*/colors.json
if [[ -n $LUAC ]]; then
  rendered_lua() {
    local out; out=$(mktemp -d)
    XDG_CONFIG_HOME=$PWD/stow/wal/.config XDG_CACHE_HOME=$out python3 tests/fake-wal.py --theme themes/tokyonight-night/colors.json &&
      "$LUAC" -p "$out/wal/colors-hyprland.lua"; local rc=$?; rm -rf "$out"; return $rc
  }
  check "rendered Hyprland colors are valid Lua" rendered_lua
fi
check_fails "unknown option is rejected" "unknown option" bash install.sh --wat
check_fails "unknown stage is rejected" "unknown stage" bash install.sh --dry-run --no-packages --only nosuchstage

if (( STATIC_ONLY )); then
  echo "== system: skipped (--static)"
else
  echo "== system (installs packages)"
  unset DOTFILES_ALLOW_NON_ARCH
  if [[ ! -f /etc/arch-release ]]; then
    skip "system tests" "not Arch Linux"
  else
    sudo pacman -Sy >/dev/null 2>&1
    check "package names resolve" bash bin/dot packages check -c "$CONFIG"
    check "dry run" bash install.sh --dry-run -c "$CONFIG"
    check "install" bash install.sh --yes -c "$CONFIG"
    second_run_is_noop() { local o; o=$(bash install.sh --yes -c "$CONFIG" 2>&1); echo "$o"; grep -q "Nothing to do" <<<"$o"; }
    check "second run changes nothing" second_run_is_noop
    check "dot is on ~/.local/bin" test -x "$HOME/.local/bin/dot"
  fi
fi

echo "== $PASS passed, $FAIL failed, $SKIP skipped"
(( FAIL == 0 ))

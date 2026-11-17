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
  lua_syntax() { local f; for f in stow/hypr/.config/hypr/*.lua $(find stow/nvim -name '*.lua'); do "$LUAC" -p "$f" || return 1; done; }
  check "Hyprland and Neovim Lua syntax" lua_syntax
else
  skip "Hyprland and Neovim Lua syntax" "no luac (pacman -S lua)"
fi
if python3 -c 'import tomllib' 2>/dev/null; then
  toml_valid() { python3 -c 'import sys, tomllib; [tomllib.load(open(f, "rb")) for f in sys.argv[1:]]' $(find stow -name '*.toml'); }
  check "TOML configs parse" toml_valid
else
  skip "TOML configs parse" "python < 3.11"
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

# NVIDIA driver choice from a fake /sys: generation by PCI device id, kernel
# variant, AUR legacy branch, and keeping an installed driver.
nvidia_choice() {
  local root id expect got
  root=$(mktemp -d)
  mkdir -p "$root/sys/bus/pci/devices/0" "$root/etc"
  echo 0x030000 > "$root/sys/bus/pci/devices/0/class"
  echo 0x10de > "$root/sys/bus/pci/devices/0/vendor"
  : > "$root/etc/pacman.conf"
  while IFS='|' read -r id kernels installed source expect; do
    echo "$id" > "$root/sys/bus/pci/devices/0/device"
    got=$(DOTFILES_SYSROOT=$root KERN="$kernels $installed" bash -c '
      source lib/common.sh; source lib/detect.sh
      has_cmd() { return 0; }
      pacman() { shift; local p r=1; for p; do [[ " $KERN " == *" $p "* ]] && { echo "$p"; r=0; }; done; return $r; }
      HAS_NVIDIA=1; nvidia_packages "$0" | tr "\n" " "' "$source")
    [[ ${got% } == "$expect" ]] || { echo "device $id, kernels [$kernels], installed [$installed], $source: got [$got], want [$expect]"; return 1; }
  done <<'CASES'
0x2684|linux||repo|nvidia-open nvidia-utils libva-nvidia-driver
0x2684|linux-lts||repo|nvidia-open-lts nvidia-utils libva-nvidia-driver
0x2684|linux linux-zen||repo|nvidia-open-dkms linux-headers linux-zen-headers nvidia-utils libva-nvidia-driver
0x2684|linux||aur|
0x1b80|linux||repo|linux-headers libva-nvidia-driver
0x1b80|linux||aur|nvidia-580xx-dkms nvidia-580xx-utils
0x0fc6|linux||repo|
0x1b80|linux|nvidia-open-dkms|repo|nvidia-utils libva-nvidia-driver
CASES
}
check "NVIDIA driver choice by GPU generation" nvidia_choice
check "every template renders with every theme" python3 tests/fake-wal.py --check stow/wal/.config/wal/templates themes/*/colors.json
# Spec, phase 4: text at least 4.5:1 and muted text at least 3:1 against the
# background (WCAG contrast), so every theme stays readable.
contrast() {
  python3 - themes/*/colors.json <<'PY'
import json, sys
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def ratio(a, b):
    hi, lo = sorted([lum(a), lum(b)], reverse=True)
    return (hi + 0.05) / (lo + 0.05)
bad = 0
for f in sys.argv[1:]:
    s = json.load(open(f))["special"]
    for key, need in [("foreground", 4.5), ("muted", 3.0)]:
        r = ratio(s[key], s["background"])
        if r < need:
            print(f"{f}: {key} {s[key]} on {s['background']} is {r:.2f}:1, needs {need}:1"); bad = 1
sys.exit(bad)
PY
}
check "every theme has readable text and muted text" contrast
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

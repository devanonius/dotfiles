#!/usr/bin/env bash
# Write packages/user.txt from the packages explicitly installed on this
# machine, minus everything the rest of the repo already handles:
#   - other modules (base.txt, desktop.txt, ...) and the AUR list
#   - hardware drivers (packages/hardware/*) and Nerd Fonts (packages/fonts/*)
#   - packages this rice replaces (packages/exclude.txt)
#   - kernel, firmware, initramfs and bootloader packages, which belong to
#     the Arch install itself and differ between machines
# AUR packages installed here are printed as suggestions for aur.txt.
#
# Usage: tools/generate-user-list.sh [--dry-run]   (--dry-run prints instead of writing)
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
# shellcheck source=lib/common.sh
source "$REPO/lib/common.sh"
require_cmd pacman

OUT=$REPO/packages/user.txt
SYSTEM_RE='^(linux(-lts|-zen|-hardened)?(-headers)?|linux-firmware.*|mkinitcpio|dracut|booster|efibootmgr|grub|systemd-boot.*|limine|refind)$'

known() {
  local f
  for f in "$REPO"/packages/*.txt "$REPO"/packages/hardware/*.txt "$REPO"/packages/fonts/*.txt; do
    [[ $f == "$OUT" ]] || read_list "$f"
  done
}

list=$(pacman -Qqen | grep -vxF -f <(known) | grep -vE "$SYSTEM_RE" || true)

header="# Owner's own packages (official repos). Hardware drivers, fonts and the
# login greeter are NOT listed here: they come from packages/hardware/,
# the font picker, and the greeter setting. Regenerate with:
#   tools/generate-user-list.sh"

if [[ ${1:-} == --dry-run ]]; then
  printf '%s\n%s\n' "$header" "$list"
else
  printf '%s\n%s\n' "$header" "$list" > "$OUT"
  log "wrote $(wc -l <<<"$list") packages to packages/user.txt"
fi

aur=$(pacman -Qqem | grep -vxF -f <(read_list "$REPO/packages/aur.txt") || true)
if [[ -n $aur ]]; then
  log "AUR packages installed here but not in packages/aur.txt (add the ones you want):"
  while read -r pkg; do printf '    %s\n' "$pkg"; done <<<"$aur"
fi

# shellcheck shell=bash
# Shared helpers for install.sh, bin/dot and the install stages.
# Sourced, never executed directly.

: "${DOTFILES_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${DOTFILES_STATE:=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles}"
: "${DOTFILES_CONFIG:=${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
export DOTFILES_DIR DOTFILES_STATE DOTFILES_CONFIG

: "${DRY_RUN:=0}"
: "${ASSUME_YES:=0}"
: "${CHANGES:=0}"

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_BLUE=$'\e[34m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_RED=$'\e[31m'
else
  C_RESET='' C_BOLD='' C_BLUE='' C_GREEN='' C_YELLOW='' C_RED=''
fi

log()  { printf '%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%s==> WARNING:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s==> ERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Record that the system is (or, in dry-run, would be) changed.
# install.sh uses the counter to prove a second run is a no-op.
changed() {
  CHANGES=$((CHANGES + 1))
  printf '    %s+%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

# Run a command that changes the system. Prints it instead under --dry-run.
run() {
  if (( DRY_RUN )); then
    printf '    [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# Print a path with $HOME shown as ~.
pretty() { local tilde='~'; printf '%s' "${1/#$HOME/$tilde}"; }

has_cmd()     { command -v "$1" >/dev/null 2>&1; }
require_cmd() { has_cmd "$1" || die "required command not found: $1"; }

# Print package names from a manifest: one per line, '#' comments and blanks ignored.
read_list() {
  [[ -f $1 ]] || return 0
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' || true
}

# Print the packages from the arguments that are not satisfied on this system.
# Uses pacman's dependency test, so a package provided by another (e.g. a -git
# variant) counts as present. Package groups are not supported by design.
missing_pkgs() {
  (( $# )) || return 0
  pacman -T "$@" || true
}

# Remove duplicate lines while keeping first-seen order.
dedupe() { awk '!seen[$0]++'; }

confirm() {
  (( ASSUME_YES )) && return 0
  local reply
  read -r -p "$1 [y/N] " reply
  [[ $reply =~ ^[Yy] ]]
}

#!/usr/bin/env bash
# Hyprland dotfiles installer. Idempotent: safe to re-run at any time.
# Usage: ./install.sh [-c FILE] [--dry-run] [--only STAGE]... [--skip STAGE]... [--no-packages] [--yes]
set -Eeuo pipefail

DOTFILES_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
export DOTFILES_DIR
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$DOTFILES_DIR/lib/config.sh"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  -c, --config FILE
                   JSON config: modules to install and extra packages
                   (pacman, aur, flatpak). Overlays config/default.json and
                   ~/.config/dotfiles/config.json. See config/example.json.
  --dry-run        print what would change, change nothing
  --only STAGE     run only this stage (repeatable); preflight, config and detect always run
  --skip STAGE     skip this stage (repeatable)
  --no-packages    deploy configs only; skip pacman and AUR stages
  --yes            non-interactive: answer yes, pass --noconfirm
  -h, --help       show this help

Stages are files in lib/install/ named NN-name.sh; refer to them by
name (pacman) or full name (20-pacman).
EOF
}

ONLY=() SKIP=() NO_PACKAGES=0
while (( $# )); do
  case $1 in
    -c|--config)
      [[ $# -ge 2 ]] || die "$1 needs a file"
      [[ -f $2 ]] || die "config file not found: $2"
      CONFIG_FILE=$(readlink -f "$2"); shift ;;
    --config=*)
      [[ -f ${1#*=} ]] || die "config file not found: ${1#*=}"
      CONFIG_FILE=$(readlink -f "${1#*=}") ;;
    --dry-run)     DRY_RUN=1 ;;
    --only)        [[ $# -ge 2 ]] || die "--only needs a stage name"; ONLY+=("$2"); shift ;;
    --skip)        [[ $# -ge 2 ]] || die "--skip needs a stage name"; SKIP+=("$2"); shift ;;
    --no-packages) NO_PACKAGES=1 ;;
    --yes|-y)      ASSUME_YES=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             usage >&2; die "unknown option: $1" ;;
  esac
  shift
done
export DRY_RUN ASSUME_YES NO_PACKAGES CONFIG_FILE

# Stages that every run needs, even with --only.
CORE_STAGES=(preflight config detect)

# matches NAME SHORT LIST... : true if NAME or SHORT is in LIST.
matches() {
  local name=$1 short=$2 item
  shift 2
  for item in "$@"; do
    [[ $item == "$name" || $item == "$short" ]] && return 0
  done
  return 1
}

selected() {
  local name=$1 short=${1#*-}
  matches "$name" "$short" "${CORE_STAGES[@]}" && return 0
  (( ${#SKIP[@]} )) && matches "$name" "$short" "${SKIP[@]}" && return 1
  (( ${#ONLY[@]} )) && ! matches "$name" "$short" "${ONLY[@]}" && return 1
  return 0
}

# Validate stage names given to --only/--skip before doing anything.
mapfile -t STAGE_FILES < <(find "$DOTFILES_DIR/lib/install" -maxdepth 1 -name '[0-9][0-9]-*.sh' | sort)
for wanted in "${ONLY[@]}" "${SKIP[@]}"; do
  found=0
  for f in "${STAGE_FILES[@]}"; do
    n=$(basename "$f" .sh)
    [[ $wanted == "$n" || $wanted == "${n#*-}" ]] && found=1
  done
  (( found )) || die "unknown stage: $wanted"
done

# Log every run. Dry runs log to /tmp so they leave no trace in $HOME.
if (( DRY_RUN )); then
  LOG_DIR=${TMPDIR:-/tmp}/dotfiles-logs
else
  LOG_DIR=$DOTFILES_STATE/logs
fi
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

INSTALL_PID=$$
SUDO_KEEPALIVE_PID=''
CURRENT_STAGE=''
export INSTALL_PID

cleanup() {
  if [[ -n $SUDO_KEEPALIVE_PID ]]; then
    pkill -P "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  return 0
}
trap cleanup EXIT
# Name the command that failed: inside sourced functions $LINENO counts
# from an offset and points at the wrong line.
trap 'printf "%s==> ERROR:%s stage %s failed (exit %s) running: %s\n    log: %s\n" "$C_RED" "$C_RESET" "${CURRENT_STAGE:-?}" "$?" "$BASH_COMMAND" "$LOG" >&2' ERR

log "dotfiles: $DOTFILES_DIR$( (( DRY_RUN )) && echo '  [dry run]')"

for f in "${STAGE_FILES[@]}"; do
  CURRENT_STAGE=$(basename "$f" .sh)
  selected "$CURRENT_STAGE" || continue
  log "[$CURRENT_STAGE]"
  unset -f stage_main
  # shellcheck source=/dev/null
  source "$f"
  stage_main
done
CURRENT_STAGE=''

if (( CHANGES == 0 )); then
  log "Nothing to do: this machine already matches the repo."
elif (( DRY_RUN )); then
  log "Dry run: $CHANGES change(s) would be made. Run without --dry-run to apply."
else
  log "Done: $CHANGES change(s) applied. Log: $LOG"
fi

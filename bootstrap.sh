#!/usr/bin/env bash
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/devanonius/dotfiles/main/bootstrap.sh | bash
# With options for install.sh (a config may be a local file or a URL):
#   curl -fsSL .../bootstrap.sh | bash -s -- -c https://example.com/my.json --dry-run
#
# Installs git, clones the repo to $DOTFILES_DIR (default ~/dotfiles) or
# updates an existing clone, then runs install.sh with the given options.
# Overrides: DOTFILES_REPO, DOTFILES_BRANCH, DOTFILES_DIR.
set -euo pipefail

REPO=${DOTFILES_REPO:-https://github.com/devanonius/dotfiles.git}
BRANCH=${DOTFILES_BRANCH:-main}
DIR=${DOTFILES_DIR:-$HOME/dotfiles}

say() { printf '\e[34m==>\e[0m \e[1m%s\e[0m\n' "$*"; }
die() { printf '\e[31m==> ERROR:\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "run as your normal user, not root; sudo is used where needed"
# DOTFILES_ARCH_RELEASE exists only so tests can run off Arch.
[[ -f ${DOTFILES_ARCH_RELEASE:-/etc/arch-release} ]] || die "this installer only supports Arch Linux"

# Download a config given as a URL, so install.sh always gets a file.
args=()
while (( $# )); do
  case $1 in
    -c|--config)
      [[ $# -ge 2 ]] || die "$1 needs a file or URL"
      if [[ $2 =~ ^https?:// ]]; then
        state=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
        mkdir -p "$state"
        say "downloading config $2"
        curl -fsSL "$2" -o "$state/bootstrap-config.json" || die "could not download $2"
        args+=("$1" "$state/bootstrap-config.json")
      else
        args+=("$1" "$(readlink -f "$2")")
      fi
      shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

if ! command -v git >/dev/null; then
  say "installing git"
  # -Syu, not -Sy: a partial upgrade is unsupported on Arch.
  sudo pacman -Syu --needed git
fi

if [[ -d $DIR/.git ]]; then
  say "updating $DIR"
  if [[ -n $(git -C "$DIR" status --porcelain) ]]; then
    say "local changes in $DIR; not pulling (commit or stash them to update)"
  else
    git -C "$DIR" pull --rebase --quiet
  fi
elif [[ -e $DIR ]]; then
  die "$DIR exists but is not a git clone; move it away or set DOTFILES_DIR"
else
  say "cloning $REPO to $DIR"
  git clone --branch "$BRANCH" "$REPO" "$DIR"
fi

# When piped from curl, stdin is the script itself; give install.sh the
# terminal so its questions (fonts, git identity, sudo) can be answered.
if { : </dev/tty; } 2>/dev/null; then
  exec bash "$DIR/install.sh" "${args[@]}" </dev/tty
else
  exec bash "$DIR/install.sh" "${args[@]}"
fi

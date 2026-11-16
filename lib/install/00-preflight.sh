# shellcheck shell=bash
# Stage 00: refuse unsafe environments and keep sudo alive for the run.

stage_main() {
  [[ $EUID -ne 0 ]] || die "run as your normal user, not root; sudo is used where needed"

  # DOTFILES_ARCH_RELEASE exists only so tests can run off Arch.
  local non_arch=0
  if [[ ! -f ${DOTFILES_ARCH_RELEASE:-/etc/arch-release} ]]; then
    if (( DRY_RUN )) && [[ ${DOTFILES_ALLOW_NON_ARCH:-0} == 1 ]]; then
      warn "not Arch Linux; continuing because this is a dry run with DOTFILES_ALLOW_NON_ARCH=1"
      non_arch=1
    else
      die "this installer only supports Arch Linux (/etc/arch-release not found)"
    fi
  fi

  (( non_arch )) || require_cmd pacman
  require_cmd git

  if ! (( NO_PACKAGES )); then
    if has_cmd curl && ! curl -fsSI --max-time 5 https://archlinux.org >/dev/null 2>&1; then
      die "no network: archlinux.org is unreachable (use --no-packages to only deploy configs)"
    fi
  fi

  if (( DRY_RUN )); then
    has_cmd jq || die "jq is needed to read the config; install it first (sudo pacman -S jq) or run without --dry-run"
    info "dry run: no sudo needed, nothing will be changed"
    return 0
  fi

  require_cmd sudo
  info "asking for sudo once for the whole run"
  sudo -v || die "sudo authentication failed"
  # Refresh the sudo timestamp until install.sh exits.
  # Detached from stdout/stderr so it never holds the log pipe open after exit.
  ( while kill -0 "$INSTALL_PID" 2>/dev/null; do sudo -n true; sleep 50; done ) </dev/null >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!

  # jq reads the install config (next stage); fresh installs do not have it.
  if ! has_cmd jq; then
    changed "install jq (needed to read the config)"
    local args=(-Syu --needed)
    (( ASSUME_YES )) && args+=(--noconfirm)
    sudo pacman "${args[@]}" jq
  fi
}

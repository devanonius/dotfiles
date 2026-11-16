# shellcheck shell=bash
# Stage 40: make zsh the login shell, install Powerlevel10k and set up the
# git identity file. Oh My Zsh and the zsh plugins are packages (stages
# 20/30); their config files are linked by stage 50.

# Powerlevel10k is not in the Arch repos. Its README's Oh My Zsh method:
# clone it into $ZSH_CUSTOM/themes and set ZSH_THEME (done in dot-zshrc).
# P10K_REPO exists so tests can use a local clone.
: "${P10K_REPO:=https://github.com/romkatv/powerlevel10k.git}"
P10K_DIR="$HOME/.config/zsh/omz-custom/themes/powerlevel10k"

set_login_shell() {
  local zsh current
  zsh=$(command -v zsh || true)
  if [[ -z $zsh ]]; then
    (( DRY_RUN )) && { info "zsh not installed yet; a real run sets it as the login shell"; return 0; }
    die "zsh is not installed (it is in packages/base.txt)"
  fi
  current=$(getent passwd "$USER" | cut -d: -f7)
  if [[ $current == "$zsh" ]]; then
    info "login shell is already zsh"
    return 0
  fi
  changed "set login shell to $zsh (was $current)"
  run sudo chsh -s "$zsh" "$USER"
}

# ~/.config/git/local holds name and email; it is untracked so every
# machine (and person) can differ. Ask once, only when someone can answer.
git_identity() {
  local file="$HOME/.config/git/local" name email
  if [[ -f $file ]]; then
    info "git identity: $(pretty "$file") exists"
    return 0
  fi
  if (( DRY_RUN || ASSUME_YES )) || ! { : >/dev/tty; } 2>/dev/null; then
    info "git identity not set; create $(pretty "$file") with [user] name/email (or re-run interactively)"
    return 0
  fi
  read -r -p "    git user.name (empty to skip): " name </dev/tty
  [[ -n $name ]] || { info "skipped"; return 0; }
  read -r -p "    git user.email: " email </dev/tty
  changed "write git identity to $(pretty "$file")"
  mkdir -p "$(dirname "$file")"
  printf '[user]\n    name = %s\n    email = %s\n' "$name" "$email" > "$file"
}

install_p10k() {
  if [[ ! -d $P10K_DIR/.git ]]; then
    changed "clone Powerlevel10k into $(pretty "$P10K_DIR")"
    run mkdir -p "$(dirname "$P10K_DIR")"
    run git clone --depth=1 --quiet "$P10K_REPO" "$P10K_DIR"
    return 0
  fi
  (( DRY_RUN )) && { info "Powerlevel10k: installed (a real run updates it)"; return 0; }
  local before after
  before=$(git -C "$P10K_DIR" rev-parse HEAD)
  if ! git -C "$P10K_DIR" pull --ff-only --quiet 2>/dev/null; then
    warn "Powerlevel10k: could not update (offline?); keeping the installed version"
    return 0
  fi
  after=$(git -C "$P10K_DIR" rev-parse HEAD)
  if [[ $before != "$after" ]]; then
    changed "update Powerlevel10k"
  else
    info "Powerlevel10k: up to date"
  fi
}

stage_main() {
  set_login_shell
  install_p10k
  git_identity
}

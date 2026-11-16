# shellcheck shell=bash
# Stage 60: install LazyVim's plugins. The config itself is the stow/nvim
# package (linked by stage 50); this only runs the first plugin sync so the
# first `nvim` opens ready instead of downloading. Later updates: `:Lazy`.

stage_main() {
  if ! has_cmd nvim; then
    (( DRY_RUN )) && { info "neovim not installed yet; a real run syncs LazyVim's plugins"; return 0; }
    warn "neovim not installed; skipped LazyVim plugin sync"
    return 0
  fi
  local data=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy
  if [[ -d $data/lazy.nvim && -d $data/LazyVim ]]; then
    info "LazyVim: plugins installed (update with :Lazy in nvim)"
    return 0
  fi
  changed "install LazyVim plugins"
  (( DRY_RUN )) && return 0
  # Plugins come from GitHub; a failure here is not fatal: nvim retries on start.
  if ! nvim --headless "+Lazy! sync" +qa >>"$LOG" 2>&1; then
    warn "LazyVim plugin sync failed (see the log); nvim installs them on first start"
  fi
}

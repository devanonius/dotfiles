export DOTFILES_DIR=${DOTFILES_DIR:-$HOME/dotfiles}
export MANPAGER='nvim +Man!'
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_dups hist_ignore_space

# fzf (CTRL-T, ALT-C, CTRL-R through the Oh My Zsh plugin): fd for file
# lists, and ANSI color numbers so it follows the active theme.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border=rounded --info=inline \
--color=fg:-1,bg:-1,hl:4,fg+:15:bold,bg+:-1,hl+:12,gutter:-1 \
--color=info:3,prompt:4,pointer:5,marker:2,spinner:5,header:6,border:8,label:8"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_OPTS="--preview 'lsd --tree --depth 2 --color=always {}'"

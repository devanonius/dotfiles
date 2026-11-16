# shellcheck shell=bash
# Stage 50: link every package in stow/ into $HOME.
#
# Files only (--no-folding), so apps that write new files into their config
# folders never write into the repo. --dotfiles: a name starting with "dot-"
# is linked as "." (stow/zsh/dot-zshrc -> ~/.zshrc), so the repo holds no
# hidden shell files. Real files in the way are moved to a
# timestamped backup, never adopted into the repo (no --adopt).

STOW_DIR_REL=stow
declare -gA BACKED_UP=()

# Print each file of a stow package relative to the package root.
package_files() {
  (cd "$DOTFILES_DIR/$STOW_DIR_REL/$1" && find . \( -type f -o -type l \) ! -name '.gitkeep' -printf '%P\n')
}

# Where a package file lands under $HOME (dot-x -> .x in every path part).
target_rel() { sed -E 's#(^|/)dot-#\1.#g' <<<"$1"; }

# Move one path into the backup dir, keeping its path relative to $HOME.
backup_path() {
  local rel=$1 backup=$2 reason=$3
  changed "back up ~/$rel ($reason)"
  run mkdir -p "$backup/$(dirname "$rel")"
  run mv "$HOME/$rel" "$backup/$rel"
}

# Move files that would block stow into the backup dir.
backup_conflicts() {
  local pkg=$1 backup=$2 rel src target parent stow_root
  stow_root=$(readlink -f "$DOTFILES_DIR/$STOW_DIR_REL")
  local file
  while read -r file; do
    src="$DOTFILES_DIR/$STOW_DIR_REL/$pkg/$file"
    rel=$(target_rel "$file")
    target="$HOME/$rel"
    # A parent folder that is a symlink to somewhere else (e.g. an old
    # dotfiles repo) is backed up as a whole link, never written through.
    parent=$(dirname "$rel")
    while [[ $parent != . ]]; do
      [[ -n ${BACKED_UP[$parent]:-} ]] && continue 2
      if [[ -L $HOME/$parent && $(readlink -f "$HOME/$parent") != "$stow_root"/* ]]; then
        backup_path "$parent" "$backup" "symlinked folder in the way of $pkg"
        BACKED_UP[$parent]=1
        continue 2
      fi
      parent=$(dirname "$parent")
    done
    if [[ -L $target ]]; then
      [[ $(readlink -f "$target") == "$(readlink -f "$src")" ]] && continue
    elif [[ ! -e $target ]]; then
      continue
    fi
    backup_path "$rel" "$backup" "in the way of $pkg"
  done < <(package_files "$pkg")
}

# Report whether a package still has files that are not linked yet.
needs_linking() {
  local pkg=$1 file rel
  while read -r file; do
    rel=$(target_rel "$file")
    [[ -L $HOME/$rel && $(readlink -f "$HOME/$rel") == "$(readlink -f "$DOTFILES_DIR/$STOW_DIR_REL/$pkg/$file")" ]] || return 0
  done < <(package_files "$pkg")
  return 1
}

# Remove symlinks that point into stow/ at files that no longer exist
# (a config deleted from the repo). Only looks where packages link to.
prune_stale_links() {
  local link dest stow_root
  stow_root=$(readlink -f "$DOTFILES_DIR/$STOW_DIR_REL")
  while IFS= read -r -d '' link; do
    [[ -e $link ]] && continue
    dest=$(readlink -m "$link")
    [[ $dest == "$stow_root"/* ]] || continue
    changed "remove stale link $(pretty "$link")"
    run rm "$link"
  done < <(
    find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null
    for d in "$HOME/.config" "$HOME/.local"; do
      [[ -d $d ]] && find "$d" -type l -print0 2>/dev/null
    done
  )
}

# Link the scripts in bin/ (dot, dot-power-menu, ...) into ~/.local/bin so
# they work before the shell config exists and from Hyprland binds.
link_cli() {
  local src name target
  # A checkout made on Windows has no executable bits; restore them.
  for src in "$DOTFILES_DIR"/bin/* "$DOTFILES_DIR/install.sh"; do
    if [[ ! -x $src ]]; then
      changed "make ${src#"$DOTFILES_DIR"/} executable"
      run chmod +x "$src"
    fi
  done
  for src in "$DOTFILES_DIR"/bin/*; do
    name=$(basename "$src")
    target="$HOME/.local/bin/$name"
    [[ -L $target && $(readlink -f "$target") == "$(readlink -f "$src")" ]] && continue
    if [[ -e $target || -L $target ]]; then
      warn "~/.local/bin/$name exists and is not this repo's script; leaving it alone"
      continue
    fi
    changed "link ~/.local/bin/$name"
    run mkdir -p "$HOME/.local/bin"
    run ln -s "$src" "$target"
  done
}

# Some configs differ between laptops and desktops. The tracked repo has
# both variants; a link next to them selects this machine's one:
#   ~/.config/wayle/layout.toml -> layout-<kind>.toml  (desktops: no battery,
#     which Wayle cannot hide and would show as "0")
#   ~/.config/hypr/idle.conf    -> idle-<kind>.conf    (hypridle timeouts)
# Wayle and hypridle need the file to exist, so this runs on every install
# right after stow.
link_machine_variant() {
  local dir=$1 link=$2 src=$3 kind=$4 target
  [[ -f $src ]] || return 0
  target="$dir/$link"
  [[ -L $target && $(readlink -f "$target") == "$(readlink -f "$src")" ]] && return 0
  if [[ -e $target && ! -L $target ]]; then
    warn "$(pretty "$target") is a regular file; leaving it (remove it to use the $kind variant)"
    return 0
  fi
  changed "$(pretty "$target") -> $kind"
  run mkdir -p "$dir"
  run ln -sfn "$src" "$target"
}

link_machine_files() {
  local kind=desktop root="$DOTFILES_DIR/$STOW_DIR_REL"
  (( ${IS_LAPTOP:-0} )) && kind=laptop
  link_machine_variant "$HOME/.config/wayle" layout.toml "$root/wayle/.config/wayle/layout-$kind.toml" "$kind"
  link_machine_variant "$HOME/.config/hypr" idle.conf "$root/hypr/.config/hypr/idle-$kind.conf" "$kind"
}

stage_main() {
  prune_stale_links

  local pkgs=() dir
  for dir in "$DOTFILES_DIR/$STOW_DIR_REL"/*/; do
    [[ -d $dir ]] && pkgs+=("$(basename "$dir")")
  done

  if (( ${#pkgs[@]} == 0 )); then
    info "no stow packages yet"
  else
    if ! has_cmd stow; then
      (( DRY_RUN )) || die "stow is not installed (it is in packages/base.txt)"
      warn "stow is not installed; a real run installs it in stage 20 first"
    fi

    local backup pkg
    backup="$DOTFILES_STATE/backup/$(date +%Y%m%d-%H%M%S)"
    for pkg in "${pkgs[@]}"; do
      if ! needs_linking "$pkg"; then
        info "$pkg: already linked"
        continue
      fi
      backup_conflicts "$pkg" "$backup"
      changed "link package $pkg"
      run stow --no-folding --dotfiles --dir="$DOTFILES_DIR/$STOW_DIR_REL" --target="$HOME" "$pkg"
    done
    [[ -d $backup ]] && info "backups saved in $backup"
  fi

  link_cli
  link_machine_files
}

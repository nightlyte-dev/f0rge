#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/nightlyte-dev/dotfiles"
REPO_NAME="dotfiles"

CONFIG_DIR="$HOME/.config"
ZSHRC_PATH="$HOME/.zshrc"
OMZ_DIR="$HOME/.oh-my-zsh"
PLUGINS_DIR="$OMZ_DIR/custom/plugins"
NVIM_DIR="$CONFIG_DIR/nvim"
STARSHIP_PATH="$CONFIG_DIR/starship.toml"

# Optional toggles (can be set by f0rge.sh when invoking this script)
#   RECLONE_PLUGINS=1  -> always rm -rf plugin dirs and clone fresh
#   UPDATE_DOTFILES=1  -> if dotfiles repo exists, hard reset it too (default: 1)
RECLONE_PLUGINS="${RECLONE_PLUGINS:-0}"
UPDATE_DOTFILES="${UPDATE_DOTFILES:-1}"

# --------------------------
# Gum wrappers (gum is assumed installed by f0rge.sh)
# --------------------------
spin() {
  local title="$1"; shift
  gum spin --title "$title" -- "$@"
}

styled() {
  local msg="$1"
  local color="${2:-141}"
  gum style --foreground "$color" "$msg"
}

warn() {
  gum style --foreground 214 "$*"
}

die() {
  gum style --foreground 196 "$*"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# --------------------------
# Backup helper (timestamped if needed)
# --------------------------
backup_path() {
  local p="$1"
  [[ -e "$p" ]] || return 0

  local ts bak
  ts="$(date +%Y%m%d-%H%M%S)"
  bak="${p}.bak"
  [[ -e "$bak" ]] && bak="${p}.bak.${ts}"

  styled "'$p' already exists, backing up to '$bak'" 141
  mv "$p" "$bak"
}

# --------------------------
# Oh-My-Zsh install (idempotent)
# --------------------------
install_omz() {
  if [[ -d "$OMZ_DIR" ]]; then
    styled "Oh-My-Zsh already installed. Skipping" 141
    return 0
  fi

  require_cmd curl
  spin "Installing Oh-My-Zsh..." bash -c \
    'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
}

# --------------------------
# Git hard sync helper
#   - fetch
#   - reset --hard to origin default branch
#   - clean -fdx
# --------------------------
git_hard_sync_to_origin_default() {
  local dest="$1"

  git -C "$dest" fetch --prune --tags origin

  # Determine origin default branch via origin/HEAD -> origin/main or origin/master
  local origin_head
  origin_head="$(git -C "$dest" symbolic-ref -q --short refs/remotes/origin/HEAD || true)"

  # Fallback if origin/HEAD isn't set
  if [[ -z "$origin_head" ]]; then
    if git -C "$dest" show-ref --verify --quiet refs/remotes/origin/main; then
      origin_head="origin/main"
    else
      origin_head="origin/master"
    fi
  fi

  git -C "$dest" reset --hard "$origin_head"
  git -C "$dest" clean -fdx
}

# --------------------------
# Plugin sync (hard reset)
# --------------------------
sync_plugin() {
  local name="$1"
  local repo="$2"
  local dest="$PLUGINS_DIR/$name"

  mkdir -p "$PLUGINS_DIR"

  if [[ "$RECLONE_PLUGINS" == "1" ]]; then
    [[ -d "$dest" ]] && spin "Removing $name (reclone mode)..." rm -rf "$dest"
    spin "Cloning $name..." git clone --depth=1 "$repo" "$dest"
    return 0
  fi

  if [[ ! -d "$dest" ]]; then
    spin "Cloning $name..." git clone --depth=1 "$repo" "$dest"
    return 0
  fi

  if [[ ! -d "$dest/.git" ]]; then
    warn "$dest exists but is not a git repo. Replacing..."
    spin "Removing invalid $name dir..." rm -rf "$dest"
    spin "Cloning $name..." git clone --depth=1 "$repo" "$dest"
    return 0
  fi

  spin "Updating $name (hard reset)..." git_hard_sync_to_origin_default "$dest"
}

install_omz_plugins() {
  install_omz

  require_cmd git

  sync_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
  sync_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
}

# --------------------------
# Dotfiles repo handling (optional update)
# --------------------------
clone_or_update_dotfiles() {
  local dest="$HOME/$REPO_NAME"

  if [[ -d "$dest/.git" ]]; then
    styled "Repository '$REPO_NAME' already exists." 141
    if [[ "$UPDATE_DOTFILES" == "1" ]]; then
      spin "Updating dotfiles repo (hard reset)..." git_hard_sync_to_origin_default "$dest"
    else
      styled "UPDATE_DOTFILES=0 set; skipping repo update." 214
    fi
    return 0
  fi

  if [[ -d "$dest" && ! -d "$dest/.git" ]]; then
    die "'$dest' exists but is not a git repository. Move/delete it and re-run."
  fi

  spin "Cloning dotfiles repository..." git clone "$REPO_URL" "$dest"
}

# --------------------------
# Apply stow (defensive)
# --------------------------
apply_stow() {
  require_cmd stow
  local dest="$HOME/$REPO_NAME"
  [[ -d "$dest" ]] || die "Dotfiles directory not found at '$dest'"

  cd "$dest"

  # If any of these folders don't exist in the repo, fail nicely
  [[ -d "zshrc" ]]    || die "Expected 'zshrc' directory in dotfiles repo, but it wasn't found."
  [[ -d "nvim" ]]     || die "Expected 'nvim' directory in dotfiles repo, but it wasn't found."
  [[ -d "starship" ]] || die "Expected 'starship' directory in dotfiles repo, but it wasn't found."

  spin "Applying dotfiles with stow..." bash -c "stow zshrc && stow nvim && stow starship"
}

# --------------------------
# Default shell to zsh
#   (kept, but assumes caller handles credentials policy)
# --------------------------
change_default_shell_to_zsh() {
  require_cmd zsh
  local zsh_bin
  zsh_bin="$(command -v zsh)"

  # Ensure zsh is valid for chsh (listed in /etc/shells)
  if [[ -f /etc/shells ]] && ! grep -qx "$zsh_bin" /etc/shells; then
    warn "$zsh_bin is not listed in /etc/shells; chsh may fail. Consider adding it."
  fi

  # Prefer non-sudo chsh first (works on many setups)
  if spin "Changing default shell to zsh..." chsh -s "$zsh_bin" "$USER"; then
    return 0
  fi

  # Fallback to sudo if needed (if your main script handles sudo, this will use cached creds)
  if command -v sudo >/dev/null 2>&1; then
    spin "Retrying shell change with sudo..." sudo chsh -s "$zsh_bin" "$USER"
  else
    warn "Could not change shell automatically. Run manually: chsh -s \"$zsh_bin\" \"$USER\""
  fi
}

# --------------------------
# Main
# --------------------------
main() {
  # gum is expected to be present (as per your main script)
  require_cmd gum

  install_omz_plugins
  clone_or_update_dotfiles

  # Backups for stow targets
  mkdir -p "$CONFIG_DIR"
  backup_path "$ZSHRC_PATH"
  backup_path "$NVIM_DIR"
  backup_path "$STARSHIP_PATH"

  apply_stow
  change_default_shell_to_zsh

  styled "Dotfiles have been installed!!" 141
  styled "You may want to reload your shell to apply changes." 141
}

main "$@"


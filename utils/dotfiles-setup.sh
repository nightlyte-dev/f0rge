#!/bin/bash

REPO_URL="https://github.com/nightlyte-dev/dotfiles"
REPO_NAME="dotfiles"
CONFIG_DIR="$HOME/.config"
ZSHRC_DIR="$HOME/.zshrc"
NVIM_DIR="$CONFIG_DIR/nvim"
STARSHIP_DIR="$CONFIG_DIR/starship.toml"
set -e

is_stow_installed() {
  pacman -Qi "stow" &> /dev/null
}

if ! is_stow_installed; then
  gum spin --title "Installing stow..." -- sudo pacman -S stow --noconfirm
fi

# Install Oh-My-Zsh with '--unattended' flag
gum spin --title "Installing Oh-My-Zsh..." -- sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$PLUGINS_DIR"
gum spin --title "Installing zsh-autosuggestions..." -- git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions" 2>&1 | grep -iE '(error|failed|fatal)' || true
gum spin --title "Installing zsh-syntax-highlighting..." -- git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting" 2>&1 | grep -iE '(error|failed|fatal)' || true

cd ~

# Check if the repository already exists
if [[ -d "$REPO_NAME" ]]; then
  gum style --foreground 141 "Repository '$REPO_NAME' already exists. Skipping clone"
else
  gum spin --title "Cloning dotfiles repository..." -- git clone "$REPO_URL" 2>&1 | grep -iE '(error|failed|fatal)' || true
fi

# Check if the clone was successful
if [ $? -eq 1 ]; then
  gum style --foreground 196 "Failed to clone the repository."
  exit 1
fi

# Backing up and renaming files if they exist so stow will work
if [[ -f "$ZSHRC_DIR" ]]; then
  gum style --foreground 141 "'~/.zshrc' already exists, creating '~/.zshrc.bak'"
  mv ~/.zshrc ~/.zshrc.bak
fi

if [[ -d "$NVIM_DIR" ]]; then
  gum style --foreground 141 "'~/.config/nvim' already exists, creating '~/.config/nvim.bak'"
  mv ~/.config/nvim/ ~/.config/nvim.bak/
fi

if [[ -f "$STARSHIP_DIR" ]]; then
  gum style --foreground 141 "'~/.config/starship.toml' already exists, creating '~/.config/starship.toml.bak'"
  mv ~/.config/starship.toml ~/.config/starship.toml.bak
fi

cd ~/"$REPO_NAME"
gum spin --title "Applying dotfiles with stow..." -- bash -c "stow zshrc && stow nvim && stow starship"

if sudo -n true 2>/dev/null; then
    # Credentials are cached, no password needed
    gum spin --title "Changing default shell to zsh..." -- sudo chsh -s $(which zsh) $USER 
else
    # Need password
    gum input --password --placeholder "Please input your password" | sudo -S chsh -s $(which zsh) $USER 
fi

gum style --foreground 141 --bold "Dotfiles have been installed!!"
gum style --foreground 141 "You may want to reload your shell to apply changes."

#!/bin/bash

# ORIGINAL_DIR=$(pwd)
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
  echo "Installing stow first"
  sudo pacman -S stow --no-confirm
fi

# Install Oh-My-Zsh with '--unattended' flag
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$PLUGINS_DIR"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"

cd ~

# Check if the repository already exists
if [[ -d "$REPO_NAME" ]]; then
  echo "Repository '$REPO_NAME' already exists. Skipping clone"
else
  git clone "$REPO_URL"
fi

# Check if the clone was successful
if [ $? -eq 1 ]; then
  echo "Failed to clone the repository."
  exit 1
fi

# If file exists, you can adopt the file and then restore the git repo files
# stow --adopt zshrc
# git restore .

# Backing up and renaming files if they exist so stow will work
if [[ -f "$ZSHRC_DIR" ]]; then
  echo "'~/.zshrc' already exists, creating '~/.zshrc.bak'"
  mv ~/.zshrc ~/.zshrc.bak
fi

if [[ -d "$NVIM_DIR" ]]; then
  echo "'~/.config/nvim' already existing, creating '~/.config/nvim.bak'"
  mv ~/.config/nvim/ ~/.config/nvim.bak/
fi

if [[ -f "$STARSHIP_DIR" ]]; then
  echo "'~/.config/starship.toml' already exists, creating '~/.config/starship.toml.bak'"
  mv ~/.config/starship.toml ~/.config/starship.toml.bak
fi

cd ~/"$REPO_NAME"
stow zshrc
stow nvim
stow starship


if sudo -n true 2>/dev/null; then
    # Credentials are cached, no password needed
    sudo chsh -s $(which zsh) $USER 
else
    # Need password
    gum input --password --placeholder "Please input your password" | sudo chsh -s $(which zsh) $USER 
fi

echo -e "Dotfiles have been installed!!\n\nYou may want to reload your shell apply changes."


#!/bin/bash

# Function to check if a package is installed
is_installed() {
  pacman -Qi "$1" &> /dev/null
}

# Function to check if a package is installed
is_group_installed() {
  pacman -Qg "$1" &> /dev/null
}

# Function to install packages if not already installed
install_packages() {
  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! is_installed "$pkg" && ! is_group_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done

  if [ ${#to_install[@]} -ne 0 ]; then
    gum style --foreground 141 "Installing: ${to_install[*]}"
    gum spin --title "Installing packages..." -- bash -c "yay -S --noconfirm ${to_install[*]} > /dev/null 2>&1"
  else
    gum style --foreground 141 "All packages already installed"
  fi
}

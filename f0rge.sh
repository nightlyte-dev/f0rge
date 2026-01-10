#!/bin/bash

# Exit on any error
set -e

# Make sure gum is installed
if ! command -v gum &>/dev/null; then
  # echo "Installing gum..."
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm gum
fi

. scripts/main.sh

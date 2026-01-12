#!/bin/bash

# Exit on any error
set -e
F0RGE_DIR=$(pwd)
# gum input --password --placeholder "Please input your password" | sudo -S sleep 1

# Make sure gum is installed
if ! command -v gum &>/dev/null; then
  # echo "Installing gum..."
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm gum
fi


# Print the logo
print_logo() {
    cat << "EOF"
    ░████   ░████                                  
   ░██     ░██ ░██                                 
░████████ ░██ ░████ ░██░████  ░████████  ░███████  
   ░██    ░██░██░██ ░███     ░██    ░██ ░██    ░██ 
   ░██    ░████ ░██ ░██      ░██    ░██ ░█████████ 
   ░██     ░██ ░██  ░██      ░██   ░███ ░██        
   ░██      ░████   ░██       ░█████░██  ░███████  
                                    ░██            
                              ░███████             
    An Upgraded Arch Linux System Crafting Tool    
                 by: nightlyte                     
       https://github.com/nightlyte-dev/f0rge      
                                                   
      Based on Typecraft's Project "Crucible"      
    (https://github.com/typecraft-dev/crucible)    

EOF
}


# Clear screen and show logo
clear
print_logo
sleep 4



# Source utility functions
if [ ! -f "utils/install-packages.sh" ]; then
  echo "Error: install-packages.sh not found!"
  exit 1
fi

source utils/install-packages.sh


# Source the package list
if [ ! -f "packages.conf" ]; then
  echo "Error: packages.conf not found!"
  exit 1
fi

source packages.conf

# Update the system first
if sudo -n true 2>/dev/null; then
    # Credentials are cached, no password needed
    gum spin --title "Updating system..." -- sudo pacman -Syu --noconfirm
else
    # Need password
    gum input --password --placeholder "Please input your password" | sudo -S gum spin --title "Updating system..." -- pacman -Syu --noconfirm
fi

# Install yay AUR helper if not present
if ! command -v yay &> /dev/null; then
  sudo -v

  gum spin --title "Getting ready for yay..." -- sudo pacman -S --needed git base-devel --noconfirm
  if [[ ! -d "yay" ]]; then
    gum style --foreground 141 'Beautiful!'
  else
    gum style --foreground 141  'yay directory already exists, removing it...'
    rm -rf yay
  fi

  gum spin --title "Cloning yay repository" -- git clone https://aur.archlinux.org/yay.git

  cd yay
  echo "building yay.... yaaaaayyyyy"
  gum spin --title "Building yay.... yaaaaayyyyy" -- bash -c 'makepkg -si --noconfirm > /dev/null 2>&1' 
  cd ..
  rm -rf yay
else
  gum style --foreground 141 'yay is already installed'
fi

clear
print_logo

PACKAGE_LIST=("System Utilities" "Dev Tools" "Media" "Office" "Fonts" "Flatpaks" "Services" "Dotfiles")

PACKAGE_CHOICE=$(gum choose --header "please select which packages to install:" --no-limit "${PACKAGE_LIST[@]}")

gum confirm "Are you sure you want to install these packages? $(gum style --foreground 212 '' "$PACKAGE_CHOICE")" \
  --affirmative "Lets Fucking Go Dude" \
  --negative "I'm outta here homie"

while IFS= read -r line; do
  case "$line" in
    "System Utilities")
      gum style --foreground 212 --bold "Installing system utilities..."
      install_packages "${SYSTEM_UTILS[@]}"
      ;;

    "Dev Tools")
      gum style --foreground 212 --bold "Installing development tools..."
      install_packages "${DEV_TOOLS[@]}"
      ;;

    "Media")
      gum style --foreground 212 --bold "Installing media packages..."
      install_packages "${MEDIA[@]}"
      ;;

    "Office")
      gum style --foreground 212 --bold "Installing office apps..."
      install_packages "${OFFICE[@]}"
      ;;

    "Fonts")
      gum style --foreground 212 --bold "Installing fonts..."
      install_packages "${FONTS[@]}"
      ;;

    "Flatpaks")
      gum style --foreground 212 --bold "Installing flatpaks (like discord and spotify)"
      . utils/install-flatpaks.sh
      ;;

    "Services")
      gum style --foreground 212 --bold "Configuring services..."
      for service in "${SERVICES[@]}"; do
        if ! systemctl is-enabled "$service" &> /dev/null; then
          gum spin --title "Enabling $service..." -- sudo systemctl enable "$service"
        else
          gum style --foreground 141 "$service is already enabled"
        fi
      done
      ;;
    
    "Dotfiles")
      gum style --foreground 212 --bold "Installing dotfiles..."
      DOTFILES_CHOICE=true
      . utils/dotfiles-setup.sh
      ;;

  esac
done <<< "$PACKAGE_CHOICE"

cd $F0RGE_DIR

SSH_AGENT_CHOICE=$(gum choose --header "Do you want to enable the SSH Agent Service?" --limit 1  "Yes" "No")
if [ "$SSH_AGENT_CHOICE" == "Yes" ]; then
  if [ "$DOTFILES_CHOICE" == true ]; then
    . utils/enable-ssh-agent.sh --use-zsh
  else
    . utils/enable-ssh-agent.sh
  fi
fi

# Completion message <3
gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Done! You may want to $(gum style --foreground 212 'reboot your system')."

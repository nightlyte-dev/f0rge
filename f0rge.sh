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
gum spin --title "Updating system..." -- sudo pacman -Syu --noconfirm

# Install yay AUR helper if not present
if ! command -v yay &> /dev/null; then
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
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
else
  gum style --foreground 141 'yay is already installed'
fi

PACKAGE_LIST=("System Utilities" "Dev Tools" "Media" "Office" "Fonts" "Flatpaks" "Services" "Dotfiles")

PACKAGE_CHOICE=$(gum choose --header "please select which packages to install:" --no-limit "${PACKAGE_LIST[@]}")

gum confirm "Are you sure you want to install these packages? $(gum style --foreground 212 '' "$PACKAGE_CHOICE")" \
  --affirmative "Lets Fucking Go Dude" \
  --negative "I'm outta here homie"


while IFS= read -r line; do
  case "$line" in
    "System Utilities")
      echo "Installing system utilities..."
      install_packages "${SYSTEM_UTILS[@]}"
      ;;

    "Dev Tools")
      echo "Installing development tools..."
      install_packages "${DEV_TOOLS[@]}"
      ;;

    "Media")
      echo "Installing media packages..."
      install_packages "${MEDIA[@]}"
      ;;

    "Office")
      echo "Installing office apps..."
      install_packages "${OFFICE[@]}"
      ;;

    "Fonts")
      echo "Installing fonts..."
      install_packages "${FONTS[@]}"
      ;;

    "Flatpaks")
      echo "Installing flatpaks (like discord and spotify)"
      . utils/install-flatpaks.sh
      ;;

    "Services")
      # Enable services
      echo "Configuring services..."
      for service in "${SERVICES[@]}"; do
        if ! systemctl is-enabled "$service" &> /dev/null; then
          echo "Enabling $service..."
          sudo systemctl enable "$service"
        else
          echo "$service is already enabled"
        fi
      done
      
      
      ;;
    
    "Dotfiles")
      echo "Installing dotfiles..."
      . utils/dotfiles-setup.sh
      ;;

  esac
done <<< "$PACKAGE_CHOICE"

cd $F0RGE_DIR

SSH_AGENT_CHOICE=$(gum choose --header "Do you want to enable the SSH Agent Service?" --limit 1  "Yes" "No")
if [ $SSH_AGENT_CHOICE == "Yes" ]; then
  . utils/enable-ssh-agent.sh
fi

# Completion message <3
gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Done! You may want to $(gum style --foreground 212 'reboot your system')."

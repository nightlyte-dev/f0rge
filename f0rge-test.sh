#!/usr/bin/env bash
set -euo pipefail

F0RGE_DIR="$(pwd)"
LOGFILE="$F0RGE_DIR/f0rge-test.log"
TEELOG="tee -a $LOGFILE"
# Exit on any error
# gum input --password --placeholder "Please input your password" | sudo -S sleep 1
# Make sure gum is installed
if ! command -v gum &>/dev/null; then
  # echo "Installing gum..."
  sudo pacman -Syu --noconfirm | $TEELOG
  sudo pacman -S --needed --noconfirm gum | $TEELOG
fi

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
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1" | $TEELOG
}


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
    styled "Installing: ${to_install[*]}" | $TEELOG
    yay -S --noconfirm "${to_install[@]}" | $TEELOG
  else
    styled "All packages already installed"
  fi
}

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
print_logo | $TEELOG 
sleep 4

# Source the package list
if [ ! -f "packages.conf" ]; then
  die "Error: packages.conf not found!" | $TEELOG
fi

source packages.conf

# Update the system first
if sudo -n true 2>/dev/null; then
    # Credentials are cached, no password needed
    spin "Updating system..." sudo pacman -Syu --noconfirm
else
    # Need password
    gum input --password --placeholder "Please input your password" | sudo -S gum spin --title "Updating system..." -- pacman -Syu --noconfirm
fi

if ! command -v yay &> /dev/null; then
  styled "Installing yay..."
  sudo ./utils/yay-install.sh 2>&1 | tee "$F0RGE_DIR/yay-install.log"
else
  styled "yay is already installed"
fi

clear
print_logo

PACKAGE_LIST=("System Utilities" "Dev Tools" "Media" "Office" "Fonts" "Flatpaks" "Services" "Dotfiles")

PACKAGE_CHOICE=$(gum choose --header "please select which packages to install:" --no-limit "${PACKAGE_LIST[@]}")

gum confirm "Are you sure you want to install these packages? $(gum style --foreground 212 '' "$PACKAGE_CHOICE")" \
  --affirmative "Lets Fucking Go Dude" \
  --negative "I'm outta here homie"
sudo -v
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
          sudo systemctl enable "$service"
        else
          warn "$service is already enabled"
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

gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Done! You may want to $(gum style --foreground 212 'reboot your system')."

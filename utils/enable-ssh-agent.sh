#!/bin/bash

if [ "$1" == "--use-zsh" ]; then
  echo "Using zsh because of dotfiles install"
  USE_ZSH=true
else
  USE_ZSH=false
fi

install -D utils/ssh-agent.service ~/.config/systemd/user/ssh-agent.service

###############################################################
# Add environment variable to user's shell configuration file #
############################################################### 

# Function to add SSH agent configuration to shell RC file
add_ssh_agent_to_shell_config() {
    # Detect user's default shell
    if [ "$USE_ZSH" == true ]; then
      USER_SHELL="zsh"
    else
      USER_SHELL=$(basename "$SHELL")
    fi
    EXPORT_LINE='export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"'
    BEGIN_MARKER="# >>> ssh-agent-setup >>>"
    END_MARKER="# <<< ssh-agent-setup <<<"

    # Determine the appropriate RC file based on shell
    case "$USER_SHELL" in
        bash)
            RC_FILE="$HOME/.bashrc"
            THEME_PATTERN="^(eval.*(starship|oh-my-posh)|source.*powerlevel|PS1=)"
            ;;
        zsh)
            RC_FILE="$HOME/.zshrc"
            THEME_PATTERN="^(eval.*(starship|oh-my-posh)|source.*powerlevel|ZSH_THEME=|PS1=)"
            ;;
        fish)
            RC_FILE="$HOME/.config/fish/config.fish"
            THEME_PATTERN="^(starship init fish|oh-my-posh init fish|theme_)"
            # Fish uses different syntax
            EXPORT_LINE='set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"'
            ;;
        ksh|mksh)
            RC_FILE="$HOME/.kshrc"
            THEME_PATTERN="^(eval.*(starship|oh-my-posh)|PS1=)"
            ;;
        tcsh|csh)
            RC_FILE="$HOME/.cshrc"
            THEME_PATTERN="^(eval.*(starship|oh-my-posh)|set prompt)"
            # CSH uses different syntax
            EXPORT_LINE='setenv SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"'
            ;;
        *)
            echo "Unsupported shell: $USER_SHELL"
            echo "Supported shells: bash, zsh, fish, ksh, mksh, tcsh, csh"
            return 1
            ;;
    esac

    echo "Detected shell: $USER_SHELL"
    echo "Configuration file: $RC_FILE"

    # Create parent directory if needed (for fish)
    RC_DIR=$(dirname "$RC_FILE")
    if [[ ! -d "$RC_DIR" ]]; then
        mkdir -p "$RC_DIR"
        echo "Created directory: $RC_DIR"
    fi

    # Create RC file if it doesn't exist
    if [[ ! -f "$RC_FILE" ]]; then
        cat > "$RC_FILE" << EOF
$BEGIN_MARKER
$EXPORT_LINE
$END_MARKER
EOF
        echo "Created $RC_FILE with SSH agent configuration"
        return 0
    fi

    # Check if our block already exists
    if grep -qF "$BEGIN_MARKER" "$RC_FILE"; then
        echo "SSH agent configuration already exists in $RC_FILE"
        return 0
    fi

    # Insert before prompt themes or append
    if grep -qE "$THEME_PATTERN" "$RC_FILE"; then
        awk -v begin="$BEGIN_MARKER" -v export="$EXPORT_LINE" -v end="$END_MARKER" -v pattern="$THEME_PATTERN" '
            !inserted && $0 ~ pattern {
                print ""
                print begin
                print export
                print end
                print ""
                inserted=1
            }
            {print}
        ' "$RC_FILE" > "$RC_FILE.tmp" && mv "$RC_FILE.tmp" "$RC_FILE"
        echo "Inserted SSH agent configuration before prompt theme in $RC_FILE"
    else
        cat >> "$RC_FILE" << EOF

$BEGIN_MARKER
$EXPORT_LINE
$END_MARKER
EOF
        echo "Appended SSH agent configuration to $RC_FILE"
    fi

    echo "SSH agent configuration successfully added to $RC_FILE"
    return 0
}

# Call the function
add_ssh_agent_to_shell_config

# Check if the function succeeded
if [[ $? -ne 0 ]]; then
    echo "Failed to configure shell RC file"
    exit 1
fi


###############################################################
# Add line to SSH config file
edit_ssh_config() {
  SSH_CONFIG_LINE="AddKeysToAgent    yes"
  SSH_DIR="$HOME/.ssh"
  SSH_CONFIG_PATH="$SSH_DIR/config"

  # Create directory if doesn't exist
  if [[ ! -d "$SSH_DIR" ]]; then
    mkdir $SSH_DIR
    echo "Created '~/.ssh' directory"
  fi

  if [[ $? -ne 0 ]]; then
    echo "Failed to make ssh directory"
    return 1
  fi

  # Create config file if doesn't exist
  if [[ ! -f "$SSH_CONFIG_PATH" ]]; then
    cat > "$SSH_CONFIG_PATH" << EOF
$SSH_CONFIG_LINE
EOF
    echo "Created $SSH_CONFIG_PATH file"
    return 0
  else
    cat >> "$SSH_CONFIG_PATH" << EOF

$SSH_CONFIG_LINE
EOF
    echo "Appended $SSH_CONFIG_PATH file"
    return 0
  fi
}

edit_ssh_config

# Check if the function succeeded
if [[ $? -ne 0 ]]; then
    echo "Failed to edit ssh config"
    exit 1
fi

# Enable custom ssh-agent service for user only (does not need sudo)
systemctl --user enable ssh-agent
if [[ $? -ne 0 ]]; then
    echo "Failed to enable ssh-agent"
    exit 1
fi

systemctl --user start ssh-agent
if [[ $? -ne 0 ]]; then
    echo "Failed to start ssh-agent"
    exit 1
fi

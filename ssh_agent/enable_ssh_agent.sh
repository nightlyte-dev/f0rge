#!/bin/bash

cp ssh_agent/ssh-agent.service ~/.config/systemd/user/ssh-agent.service

# Put command to add the following line to .zshrc here
# export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

systemctl --user enable ssh-agent
systemctl --user start ssh-agent

# Put command to add the following line to ~/.ssh/config here
# AddKeysToAgent    yes

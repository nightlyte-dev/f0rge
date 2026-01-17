#!/usr/bin/env bash

set -euo pipefail
pacman -Sy --needed --noconfirm sudo wget base-devel

# Set up passwordless-sudo for the aur helper account
printf "aur   ALL = (root) NOPASSWD: /usr/bin/makepkg, /usr/bin/pacman" > /etc/sudoers.d/02_aur

useradd -m aur || true

# Install package-query
su - aur -c bash -c 'rm -rf /tmp/package-query ; mkdir -p /tmp/package-query ; cd /tmp/package-query ; wget https://aur.archlinux.org/cgit/aur.git/snapshot/package-query.tar.gz ; tar zxvf package-query.tar.gz ; cd package-query ; makepkg --syncdeps --rmdeps --install --noconfirm'

# Install yay
su - aur -c bash -c 'rm -rf /tmp/yay ; mkdir -p /tmp/yay ; cd /tmp/yay ; wget https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz ; tar zxvf yay.tar.gz ; cd yay ; makepkg --syncdeps --rmdeps --install --noconfirm'

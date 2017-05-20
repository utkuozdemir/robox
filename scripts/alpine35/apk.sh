#!/bin/sh

# Configure the main repository mirrors.
printf "https://dl-3.alpinelinux.org/alpine/v3.5/main\nhttps://mirror.leaseweb.com/alpine/v3.5/main\n" > /etc/apk/repositories

# Update the package list and then upgrade.
apk update --no-cache
apk update upgrade

# Install various basic system utilities.
apk add vim man man-pages bash gawk wget curl sudo lsof file grep readline mdocml sysstat lm_sensors findutils sysfsutils dmidecode libmagic sqlite-libs ca-certificates ncurses-libs ncurses-terminfo ncurses-terminfo-base

# Setup vim as the default editor.
printf "alias vi=vim\n" >> /etc/profile.d/vim.sh

# Run the updatedb script so the locate command works.
updatedb

# Reboot onto the new kernel (if applicable).
reboot

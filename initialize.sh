#!/bin/sh

set -e -o pipefail
set -x

alias pacman='pacman --noconfirm'

# Filter and sort mirrorlist for speed
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
awk '/^## North America$/{f=1; next}f==0{next}/^$/{exit}{print substr($0, 1);}' /etc/pacman.d/mirrorlist.backup \
	> /etc/pacman.d/mirrorlist.na

rankmirrors /etc/pacman.d/mirrorlist.na | tee /etc/pacman.d/mirrorlist

# Install kernel and firmware
pacman -S linux linux-firmware

# Timezone and clock
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc

# Locale
sed -i 's/^#en_US/en_US/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Cleanup
rm /initialize.sh

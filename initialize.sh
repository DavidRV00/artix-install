#!/bin/sh

set -e -o pipefail
set -x

alias pacman='pacman --noconfirm'

drive="$1"

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

# Network management
pacman -S networkmanager networkmanager-runit connman connman-runit
ln -s /etc/runit/sv/NetworkManager/ /etc/runit/runsvdir/current
ln -s /etc/runit/sv/connmand/ /etc/runit/runsvdir/current

# Hosts and hostname
set +x
echo
echo "Enter hostname: "
read hn
echo "$hn" > /etc/hostname

cat << EOF >> /etc/hosts

127.0.0.1	localhost
::1		localhost
127.0.1.1	$hn.localdomain $hn
EOF

# Bootloader
set -x
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Root password
set +x
echo
echo "root:"
passwd

# Non-root user
echo
echo "Enter username: "
read username

set -x
useradd -m "$username"
usermod -a -G wheel,users "$username"
set +x

echo
echo "$username:"
passwd "$username"

set -x

# Sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

cat << EOF >> /etc/sudoers

## Don't need to reinsert password in each different terminal a wheel user uses sudo in.
Defaults !tty_tickets
EOF

set +x


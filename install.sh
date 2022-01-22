#!/bin/sh

# This script installs a non-UEFI, ext4, runit system with partitions for /, /boot, and /home.

if [ "$(id -u)" != 0 ]; then
	echo "Must be run as root."
	exit 1
fi

# Check UEFI or not
ls /sys/firmware/efi/efivars
if [ $? -eq 0 ]; then
	echo UEFI
	exit 1
fi
echo

# Check internet
ping -c 3 artixlinux.org
[ $? -eq 0 ] || exit 1
echo

set -x

# Install prereqs
alias pacman='pacman --noconfirm'

pacman -Sy
pacman -S fzf

alias fzf='fzf --layout=reverse'
alias lsblk='lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINTS,LABEL,UUID'
echo

# Set up partitions
set +x
drive="$(lsblk --nodeps | tail -n +2 | fzf --prompt="Select a drive to partition: " | awk '{print $1}')"
[ "$drive" == "" ] && exit 1

echo "************************************************************************"
echo "Set up your partitions on drive: /dev/$drive"
echo
echo "Hints:"
echo "  p: list partitions"
echo "  d: delete partition"
echo "  n: create new partition"
echo "  w: write changes"
echo "  q: quit without writing"
echo
echo "Guidelines:"
echo "  1. delete all partitions"
echo "  2. create /boot partition (default first sector; +1G size)"
echo "  3. create / partition (default first sector; +30G size)"
echo "  4. create /home partition (default first sector; default last sector)"
echo "  5. write partitions"
echo "************************************************************************"

fdisk /dev/"$drive"
echo

# Create filesystems
get_part() {
	prompt="$1"
	part="$(lsblk --list | grep "^$drive[0-9]\+.*" | fzf --prompt="$prompt" | awk '{print $1}')"
	echo "$part"
}

while true; do
	part=$( get_part "Select a partition to format to ext4 (esc to stop): " )
	[ "$part" != "" ] || break
	set -x
	mkfs.ext4 /dev/"$part"
	set +x
done
echo

# Mount partitions
mount_part() {
	dir="$1"
	while true; do
		part=$( get_part "Select the $dir partition to mount: " )
		[ "$part" != "" ] || continue
		set -x
		mkdir -p /mnt"$dir"
		mount /dev/"$part" /mnt"$dir"
		set +x
		break
	done
}

mount_part "/"
mount_part "/boot"
mount_part "/home"
echo

lsblk
echo

# Install base operating system
read -p "Continue to install base operating system to /dev/$drive [y/n]? " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

set -x
basestrap /mnt base base-devel runit elogind-runit pacman-contrib

# Basic initial system setup
cp fstab-clean /mnt/etc/fstab
fstabgen -U /mnt >> /mnt/etc/fstab

cp ./initialize.sh /mnt/
artix-chroot /mnt sudo sh ./initialize.sh

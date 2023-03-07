#!/bin/bash

# Set variables
HOSTNAME="test-vm"
TIMEZONE="Asia/Kolkata"

# Exit immediately if any command fails
set -e

# Set up keyboard layout
loadkeys us

# Connect to the internet
dhcpcd

# Update the system clock
timedatectl set-ntp true

# Partition the disk
# Assuming the disk is /dev/sda
# and the partition table is GPT
sgdisk -Z /dev/sda
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" /dev/sda
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Arch Linux" /dev/sda

# Format the partitions
mkfs.fat -F32 /dev/sda1
mkfs.btrfs /dev/sda2

# Mount the root partition
mount /dev/sda2 /mnt

# Create and mount the subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt

mount -o subvol=@,compress=zstd /dev/sda2 /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o subvol=@home,compress=zstd /dev/sda2 /mnt/home
mount -o subvol=@log,compress=zstd /dev/sda2 /mnt/var/log
mount -o subvol=@pkg,compress=zstd /dev/sda2 /mnt/var/cache/pacman/pkg
mount -o subvol=@snapshots,compress=zstd /dev/sda2 /mnt/.snapshots
mount /dev/sda1 /mnt/boot

# Set the mirrorlist to an Indian mirror using Reflector and rsync
pacman -Syy reflector
reflector --country India --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Install the base system and KDE packages
pacstrap /mnt base base-devel linux linux-firmware nano btrfs-progs sddm plasma kde-applications

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF
# Set the hostname
echo $HOSTNAME > /etc/hostname
# Set the timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
# Set the locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
# Enable parallel downloading
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
# Install and configure GRUB
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
# Enable and start SDDM
systemctl enable sddm.service
systemctl start sddm.service
# Set a root password
passwd
# Create a non-root user
useradd -m -G wheel username
passwd username
# Exit chroot

# Exit chroot environment and reboot into the new system
exit
umount -R /mnt
reboot
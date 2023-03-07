#!/bin/bash

# Update system clock
timedatectl set-ntp true

# Partition the disk (assumes /dev/sda is the target disk)
# You may need to adjust this section to match your specific partitioning needs
parted /dev/sda mklabel gpt
parted /dev/sda mkpart ESP fat32 1MiB 513MiB
parted /dev/sda set 1 boot on
parted /dev/sda mkpart primary ext4 513MiB 100%
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# Install Arch Linux base system
pacstrap /mnt base base-devel linux linux-firmware efibootmgr

# Generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash

# Set timezone (replace with your own timezone)
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# Generate locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "myhostname" > /etc/hostname

# Add hosts entry
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts

# Install KDE desktop environment and GDM display manager
pacman -S kde plasma-meta gdm

# Enable GDM service
systemctl enable gdm.service

# Set root password
passwd

# Exit chroot environment and reboot into the new system
exit
umount -R /mnt
reboot
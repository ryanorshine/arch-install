#!/bin/bash
set -e  # Exit on any error

# Variables
DISK="/dev/sdb5"  # Adjust if your M.2 drive identifier is different
HOSTNAME="archy"
USER="archy"
PASSWORD="ryan"
KEYBOARD="us"
LOCALE_MAIN="en_US.UTF-8"
LOCALE_SECONDARY="de_DE.UTF-8"

# Partitioning and Formatting
echo "Partitioning the disk..."
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 512MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary ext4 512MiB 100%

echo "Formatting partitions..."
mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"

echo "Mounting partitions..."
mount "${DISK}p2" /mnt
mkdir /mnt/boot
mount "${DISK}p1" /mnt/boot

# Base Installation
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano vim networkmanager amd-ucode

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and Configuration
echo "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF
    # Timezone
    echo "Setting timezone to auto-detect..."
    timedatectl set-ntp true

    # Locale
    echo "$LOCALE_MAIN UTF-8" > /etc/locale.gen
    echo "$LOCALE_SECONDARY UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE_MAIN" > /etc/locale.conf
    echo "KEYMAP=$KEYBOARD" > /etc/vconsole.conf

    # Hostname and Hosts
    echo "$HOSTNAME" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" > /etc/hosts

    # Root Password
    echo "root:$PASSWORD" | chpasswd

    # Bootloader
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Create User
    useradd -m $USER
    echo "$USER:$PASSWORD" | chpasswd
    usermod -aG wheel $USER
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    # Install GNOME and Display Manager
    pacman -S --noconfirm xorg gdm gnome gnome-extra gnome-tweaks
    systemctl enable gdm
    systemctl enable NetworkManager

    # Install NVIDIA Drivers
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils cuda

    # Python and Miniforge
    pacman -S --noconfirm python python-pip python-virtualenv
    curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o /tmp/Miniforge3.sh
    bash /tmp/Miniforge3.sh -b -p /opt/miniforge3
    ln -s /opt/miniforge3/bin/conda /usr/bin/conda
    conda init bash

    # Install Additional Applications
    pacman -S --noconfirm firefox thunderbird nano
EOF

# Unmount and Finish
echo "Unmounting partitions..."
umount -R /mnt
echo "Installation complete! Reboot your system."

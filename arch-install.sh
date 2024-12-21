#!/bin/bash
set -e  # Exit on any error

# Variables
DISK="/dev/sdX"  # Replace with your SSD device (e.g., /dev/sda or /dev/nvme0n1)
HOSTNAME="archy"
ROOT_PASSWORD="rootpass"
USER="archuser"
USER_PASSWORD="userpass"
KEYBOARD="us"
LOCALE="en_US.UTF-8"

# Partitioning and Formatting
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 512MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary ext4 512MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

mount "${DISK}2" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# Base Installation
pacstrap /mnt base linux linux-firmware networkmanager

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and Configuration
arch-chroot /mnt /bin/bash <<EOF
    # Timezone and Locale
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    echo "$LOCALE UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" > /etc/locale.conf
    echo "KEYMAP=$KEYBOARD" > /etc/vconsole.conf

    # Hostname and Networking
    echo "$HOSTNAME" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" > /etc/hosts
    echo "root:$ROOT_PASSWORD" | chpasswd

    # User Account
    useradd -m $USER
    echo "$USER:$USER_PASSWORD" | chpasswd
    usermod -aG wheel $USER
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    # Bootloader
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Essential Tools and Fonts
    pacman -S --noconfirm base-devel python python-pip vim ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji

    # Desktop Environment and GNOME
    pacman -S --noconfirm xorg gdm gnome gnome-themes-extra gnome-shell-extensions
    systemctl enable gdm
    systemctl enable NetworkManager

    # Sound Drivers (Realtek HD)
    pacman -S --noconfirm alsa-utils pulseaudio pavucontrol sof-firmware
    pulseaudio --start
    alsactl init
EOF

umount -R /mnt
echo "Installation complete! Reboot your system."

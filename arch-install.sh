#!/bin/bash
set -e  # Exit on any error

# Variables
ROOT_DISK="/dev/sda"  # Replace with your root SSD device
HOME_DISK="/dev/sdb"  # Replace with your home SSD device
SWAP_SIZE="8G"        # Adjust swap size here
HOSTNAME="archy"
ROOT_PASSWORD="rootpass"
USER="archuser"
USER_PASSWORD="userpass"
KEYBOARD="us"
LOCALE="en_US.UTF-8"

# Partitioning and Formatting Root Disk
echo "Partitioning and formatting root disk ($ROOT_DISK)..."
parted -s $ROOT_DISK mklabel gpt
parted -s $ROOT_DISK mkpart primary fat32 1MiB 512MiB
parted -s $ROOT_DISK set 1 esp on
parted -s $ROOT_DISK mkpart primary ext4 512MiB -${SWAP_SIZE}
parted -s $ROOT_DISK mkpart primary linux-swap -${SWAP_SIZE} 100%
mkfs.fat -F32 "${ROOT_DISK}1"  # EFI partition
mkfs.ext4 "${ROOT_DISK}2"      # Root partition
mkswap "${ROOT_DISK}3"         # Swap partition

# Enable Swap
echo "Enabling swap..."
swapon "${ROOT_DISK}3"

# Mounting Partitions
echo "Mounting partitions..."
mount "${ROOT_DISK}2" /mnt
mkdir /mnt/boot
mount "${ROOT_DISK}1" /mnt/boot
mkdir /mnt/home
mount "${HOME_DISK}1" /mnt/home

# Base Installation
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware networkmanager

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Add Swap to fstab
echo "Adding swap to fstab..."
echo "${ROOT_DISK}3 none swap defaults 0 0" >> /mnt/etc/fstab

# Chroot and Configuration
echo "Entering chroot environment for configuration..."
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

    # Additional Software
    pacman -S --noconfirm vlc firefox p7zip unrar unzip tar
EOF

# Unmount Partitions
echo "Unmounting partitions..."
umount -R /mnt

echo "Installation complete! Reboot your system."

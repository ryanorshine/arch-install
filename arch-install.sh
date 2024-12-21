#!/bin/bash
set -e  # Exit on error

# Variables
ROOT_DISK="/dev/sda"  # Replace with your root disk
HOME_PART="/dev/sdb1" # Replace with your home partition
SWAP_SIZE="34G"       # Size of swap file
ZRAM_SIZE="4096"      # ZRAM size in MB
HOSTNAME="archy"
USER="archuser"
USER_PASSWORD="your_password_here"

# Partitioning and Formatting Root Disk
echo "Partitioning and formatting root disk ($ROOT_DISK)..."
parted -s $ROOT_DISK mklabel gpt
parted -s $ROOT_DISK mkpart primary fat32 1MiB 513MiB
parted -s $ROOT_DISK set 1 esp on
parted -s $ROOT_DISK mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "${ROOT_DISK}1"
mkfs.ext4 -F "${ROOT_DISK}2" -E discard

# Mount Partitions
echo "Mounting partitions..."
mount "${ROOT_DISK}2" /mnt
mkdir /mnt/boot
mount "${ROOT_DISK}1" /mnt/boot
mkdir /mnt/home
mount "${HOME_PART}" /mnt/home

# Base Installation
echo "Installing base system..."
pacstrap /mnt base linux-zen linux-firmware amd-ucode networkmanager reflector base-devel apparmor zram-generator

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure Swap
echo "Configuring swap..."
arch-chroot /mnt /bin/bash <<EOF
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    echo "/swapfile none swap sw,pri=1 0 0" >> /etc/fstab
    swapon /swapfile
EOF

# Configure ZRAM
echo "Configuring ZRAM..."
cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = $ZRAM_SIZE
compression-algorithm = lz4
EOF

# Configure System
arch-chroot /mnt /bin/bash <<EOF
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "$HOSTNAME" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" > /etc/hosts

    useradd -m $USER
    echo "$USER:$USER_PASSWORD" | chpasswd
    usermod -aG wheel $USER
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    pacman -S --noconfirm grub efibootmgr nvidia-dkms nvidia-utils linux-zen-headers xorg gdm gnome firefox vlc p7zip unzip tar
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    systemctl enable gdm
    systemctl enable NetworkManager
    systemctl enable systemd-timesyncd
    systemctl enable systemd-zram-setup@zram0

    # DKMS for NVIDIA
    dkms install nvidia/$(pacman -Qi nvidia | grep Version | awk '{print $3}')
EOF

# Finish Up
umount -R /mnt
echo "Installation complete! Reboot your system."

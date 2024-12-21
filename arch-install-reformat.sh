#!/bin/bash
set -e  # Exit on any error

# Variables
ROOT_DISK="/dev/sda"  # Replace with your root SSD device
HOME_DISK="/dev/sdb"  # Replace with your home SSD device
SWAP_SIZE="34G"       # Disk-based swap size for hibernation
ZRAM_SIZE="8G"        # ZRAM size for compressed swap
HOSTNAME="archy"
USER="archuser"
USER_PASSWORD="your_strong_password_here"

# Partitioning and Formatting Root Disk
echo "Partitioning and formatting root disk ($ROOT_DISK)..."
parted -s $ROOT_DISK mklabel gpt
parted -s $ROOT_DISK mkpart primary fat32 1MiB 513MiB
parted -s $ROOT_DISK set 1 esp on
parted -s $ROOT_DISK mkpart primary ext4 513MiB 100%
mkfs.fat -F32 "${ROOT_DISK}1"  # EFI partition
mkfs.ext4 -F "${ROOT_DISK}2" -E discard  # Root partition with TRIM

# Partitioning and Formatting Home Disk
echo "Partitioning and formatting home disk ($HOME_DISK)..."
parted -s $HOME_DISK mklabel gpt
parted -s $HOME_DISK mkpart primary ext4 1MiB 100%
mkfs.ext4 -F "${HOME_DISK}1" -E discard  # Home partition with TRIM

# Mounting Partitions
echo "Mounting partitions..."
mount "${ROOT_DISK}2" /mnt
mkdir /mnt/boot
mount "${ROOT_DISK}1" /mnt/boot
mkdir /mnt/home
mount "${HOME_DISK}1" /mnt/home

# Base Installation
echo "Installing base system..."
pacstrap /mnt base linux-zen linux-firmware amd-ucode networkmanager reflector git base-devel apparmor zram-generator

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Add Disk-Based Swap for Hibernation
echo "Creating swap file for hibernation..."
arch-chroot /mnt /bin/bash <<EOF
    fallocate -l ${SWAP_SIZE} /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    echo "/swapfile none swap sw,pri=1 0 0" >> /etc/fstab
    swapon /swapfile
EOF

# Configure ZRAM
echo "Configuring ZRAM..."
cat <<EOF > /mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = lz4
EOF

# Chroot and Configuration
echo "Entering chroot environment for configuration..."
arch-chroot /mnt /bin/bash <<EOF
    # Timezone and Locale
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    # Hostname and Networking
    echo "$HOSTNAME" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" > /etc/hosts

    # Create User Account
    useradd -m $USER
    echo "$USER:$USER_PASSWORD" | chpasswd
    usermod -aG wheel $USER
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    # Bootloader
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Enable NTP
    systemctl enable --now systemd-timesyncd.service

    # Enable ZRAM
    systemctl enable --now /dev/zram0

    # Enable CPU Performance Governor
    pacman -S --noconfirm cpupower
    echo "governor='performance'" >> /etc/default/cpupower
    systemctl enable --now cpupower.service

    # Firewall Configuration
    pacman -S --noconfirm ufw
    systemctl enable --now ufw.service
    ufw default deny incoming
    ufw default allow outgoing
    ufw enable

    # Essential Tools and Fonts
    pacman -S --noconfirm base-devel python python-pip vim ttf-dejavu ttf-liberation noto-fonts noto-fonts-cjk noto-fonts-emoji

    # Desktop Environment and GNOME
    pacman -S --noconfirm xorg gdm gnome gnome-themes-extra gnome-shell-extensions
    systemctl enable gdm
    systemctl enable NetworkManager

    # Additional Software
    pacman -S --noconfirm vlc firefox p7zip unrar unzip tar
EOF

# Unmount Partitions
echo "Unmounting partitions..."
umount -R /mnt

echo "Installation complete! Reboot your system."

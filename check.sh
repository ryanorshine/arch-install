#!/bin/bash

echo "Running post-reboot checks..."

# Check swap status
echo "Checking swap status..."
swapon --show

# Check ZRAM status
echo "Checking ZRAM status..."
zramctl

# Check user permissions
echo "Checking user permissions..."
id $(whoami)

# Check NetworkManager status
echo "Checking NetworkManager status..."
systemctl status NetworkManager | grep Active

# Check firewall status
echo "Checking UFW status..."
sudo ufw status

# Check desktop environment
echo "Checking if GDM is running..."
systemctl status gdm | grep Active

# Check system updates
echo "Checking for updates..."
sudo pacman -Syu --noconfirm

echo "Startup checks completed!"

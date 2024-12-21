#!/bin/bash

echo "Running post-reboot checks..."

# Check swap status
echo "Checking swap status..."
swapon --show

# Check ZRAM status
echo "Checking ZRAM status..."
zramctl

# Check NetworkManager status
echo "Checking NetworkManager status..."
systemctl is-active NetworkManager

# Check GDM (GNOME Display Manager) status
echo "Checking GDM status..."
systemctl is-active gdm

# Check UFW (firewall) status
echo "Checking UFW status..."
ufw status

echo "Post-reboot checks completed!"

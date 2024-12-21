#!/bin/bash

echo "Running post-reboot checks..."

# Check swap
echo "Checking swap status..."
swapon --show

# Check ZRAM
echo "Checking ZRAM status..."
zramctl

# Check NVIDIA
echo "Checking NVIDIA driver..."
nvidia-smi

# Check GDM
echo "Checking GDM status..."
systemctl is-active gdm

echo "Post-reboot checks complete!"

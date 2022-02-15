#!/bin/bash
# This script will be executed user_data_linux.sh
# and before the platform-specific script during deployment

# Ubuntu customization

# Prep for NFS mount (MSR 2.x prerequisites)
apt update -y
apt install -y nfs-common

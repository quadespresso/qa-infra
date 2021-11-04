#!/bin/bash
# This script will be appended to user_data_linux.sh during deployment

# RHEL 8.4 customization

# disable problematic component
systemctl disable nm-cloud-setup || true
yum -y remove NetworkManager-cloud-setup
# report state to user-init log
ip rule show

# ensure correct state after changes
reboot

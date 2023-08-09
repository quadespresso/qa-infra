#!/bin/bash
# Common base script for all Linux platforms.
echo "Update hostname with FQDN"
HOSTNAME="$(hostname -f)"
hostnamectl set-hostname "${HOSTNAME}"
hostnamectl status

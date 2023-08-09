#!/bin/bash

echo "Prep zypper repos"

echo "Add OpenSUSE utilities repo"
REPO_GPG_KEY_FILE=/tmp/OpenSUSE_repomd.xml.key
SUSE_VER=$(cat /etc/os-release | awk -F '"' '/VERSION_ID/ {print $2}')
zypper addrepo "https://download.opensuse.org/repositories/utilities/${SUSE_VER}/utilities.repo"
curl -so "${REPO_GPG_KEY_FILE}" "https://download.opensuse.org/repositories/utilities/${SUSE_VER}/repodata/repomd.xml.key"
rpm --import "${REPO_GPG_KEY_FILE}"
